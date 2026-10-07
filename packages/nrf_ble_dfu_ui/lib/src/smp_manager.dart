import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:convert/convert.dart';
import 'package:cbor/cbor.dart' as cbor_pkg;
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

/// Carries SMP over a flutter_blue_plus connection.
class SmpManager implements SmpTransport {
  static final String smpServiceUuid = DfuProtocol.zephyr.serviceUuid;
  static const String smpCharacteristicUuid = "DA2E7828-FBCE-4E01-AE9E-261174997C48";

  final BluetoothDevice device;
  BluetoothCharacteristic? _smpCharacteristic;
  StreamSubscription? _notificationSubscription;

  final Map<int, Completer<Map>> _pendingRequests = {};
  Uint8List _responseBuffer = Uint8List(0);
  int _expectedLength = -1;
  int _sequence = 0;
  StreamSubscription? _connectionSubscription;

  /// Where diagnostics go, if anywhere.
  ///
  /// A library has no business writing to stdout: it corrupts the output of
  /// any tool built on it, and in an app it goes to a console nobody is
  /// looking at. Silent unless a caller asks for these.
  final void Function(String message)? onLog;

  SmpManager(this.device, {this.onLog});

  @override
  int get mtu => device.mtuNow;

  Future<void> connect() async {
    await device.connect(license: License.free);
    
    // Request MTU increase only on Android. Windows/iOS handle this at the OS level.
    if (Platform.isAndroid) {
      try {
        await device.requestMtu(251).timeout(const Duration(seconds: 2));
      } catch (e) {
        onLog?.call("MTU request failed: $e");
      }
    } else {
      // On Windows/iOS, we just read whatever the OS negotiated
      try {
        final currMtu = await device.mtu.first.timeout(const Duration(seconds: 1));
        onLog?.call("Negotiated MTU: $currMtu");
      } catch (_) {}
    }

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.toString().toLowerCase() == smpServiceUuid.toLowerCase()) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == smpCharacteristicUuid.toLowerCase()) {
            _smpCharacteristic = char;
            break;
          }
        }
      }
    }

    if (_smpCharacteristic == null) {
      throw Exception("SMP Characteristic not found");
    }

    await _smpCharacteristic!.setNotifyValue(true);
    await Future.delayed(const Duration(milliseconds: 100)); // Wait for notify to settle

    _notificationSubscription = _smpCharacteristic!.onValueReceived.listen(_handleNotification);

    // Monitor for disconnection
    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _handleDisconnection();
      }
    });
  }

  void _handleDisconnection() {
    onLog?.call("SmpManager: Device disconnected. Clearing ${_pendingRequests.length} pending requests.");
    for (var completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception("Device disconnected"));
      }
    }
    _pendingRequests.clear();
    _responseBuffer = Uint8List(0);
    _expectedLength = -1;
  }

  void _handleNotification(List<int> data) {
    _responseBuffer = Uint8List.fromList([..._responseBuffer, ...data]);

    while (_responseBuffer.length >= SmpHeader.headerLength) {
      if (_expectedLength == -1) {
        final header = SmpHeader.fromBytes(_responseBuffer);
        _expectedLength = header.length + SmpHeader.headerLength;
      }

      if (_responseBuffer.length >= _expectedLength) {
        final fullResponse = _responseBuffer.sublist(0, _expectedLength);
        final header = SmpHeader.fromBytes(fullResponse);
        final payloadPart = fullResponse.sublist(SmpHeader.headerLength);

        // Advance buffer
        _responseBuffer = _responseBuffer.sublist(_expectedLength);
        _expectedLength = -1;

        try {
          final decoded = cbor_pkg.cbor.decode(payloadPart.toList());
          final responseMap = decoded.toObject() as Map;
          onLog?.call("SMP Response (seq: ${header.sequence}): $responseMap");

          final completer = _pendingRequests.remove(header.sequence);
          if (completer != null && !completer.isCompleted) {
            completer.complete(responseMap);
          }
        } catch (e) {
          onLog?.call("Error decoding SMP response: $e");
        }
      } else {
        break; // Wait for more data
      }
    }
  }

  Future<void> disconnect() async {
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _handleDisconnection();
    await device.disconnect();
  }

  cbor_pkg.CborValue _toCbor(dynamic value) {
    if (value is Map) {
      return cbor_pkg.CborMap({
        for (var entry in value.entries) _toCbor(entry.key): _toCbor(entry.value),
      });
    } else if (value is Uint8List) {
      return cbor_pkg.CborBytes(value);
    } else if (value is List<int>) {
      return cbor_pkg.CborBytes(Uint8List.fromList(value));
    } else if (value is String) {
      return cbor_pkg.CborString(value);
    } else if (value is int) {
      return cbor_pkg.CborInt(BigInt.from(value));
    } else if (value is bool) {
      return cbor_pkg.CborBool(value);
    }
    return cbor_pkg.CborValue(value);
  }

  @override
  Future<Map<dynamic, dynamic>> sendRequest(
    int op,
    int group,
    int commandId,
    Map<dynamic, dynamic> payload,
  ) async {
    if (_smpCharacteristic == null) throw Exception("Not connected");

    Uint8List payloadBytes;
    if (payload.isEmpty) {
      // For Read operations (op 0), some devices prefer 0 bytes.
      // For others (Write), 0xa0 is standard.
      if (op == SmpOp.read) {
        payloadBytes = Uint8List(0);
      } else {
        payloadBytes = Uint8List.fromList([0xa0]);
      }
    } else {
      final encoded = cbor_pkg.cbor.encode(_toCbor(payload));
      payloadBytes = Uint8List.fromList(encoded);
    }

    final seq = _sequence++;
    if (_sequence > 255) _sequence = 0;

    final header = SmpHeader(
      op: op,
      flags: 0,
      length: payloadBytes.length,
      group: group,
      sequence: seq,
      commandId: commandId,
    );

    final packet = Uint8List(SmpHeader.headerLength + payloadBytes.length);
    packet.setAll(0, header.toBytes());
    packet.setAll(SmpHeader.headerLength, payloadBytes);

    onLog?.call("SMP Request (seq: $seq): ${hex.encode(packet)}");

    final completer = Completer<Map>();
    _pendingRequests[seq] = completer;

    // Reliability: For small packets, use simple write. For large, rely on allowLongWrite.
    // If MTU is 23, total packet must be <= 20 to avoid ATT fragmentation.
    try {
      if (packet.length <= 20) {
        await _smpCharacteristic!.write(packet, withoutResponse: true);
      } else {
        // Prepare/Execute Write for packets > MTU
        await _smpCharacteristic!.write(packet, allowLongWrite: true);
      }
    } catch (e) {
      onLog?.call("SMP Write error: $e. Attempting fallback...");
      await _smpCharacteristic!.write(packet, withoutResponse: true);
    }

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pendingRequests.remove(seq);
        throw TimeoutException("SMP Response timeout (seq: $seq)");
      },
    );
  }
}

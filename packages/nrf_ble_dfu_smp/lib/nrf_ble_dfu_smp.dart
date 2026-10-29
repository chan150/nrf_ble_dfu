import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_blue_rs/flutter_blue_plus.dart';
import 'package:convert/convert.dart';
import 'package:cbor/cbor.dart' as cbor_pkg;
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

/// Carries SMP over a flutter_blue_rs connection (its FlutterBluePlus API).
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

  /// mcumgr's receive buffer, from its params; null if it did not say.
  int? _bufSize;

  /// The link MTU, capped so an upload frame (at most `mtu - 4` bytes, see
  /// [smpFrameOverhead]) fits the device's buffer. Without its params the cap
  /// is 251, the MTU this always ran with.
  @override
  int get mtu => math.min(device.mtuNow, _bufSize ?? 251);

  /// mcumgr's buffer count, from its params; null if it did not say.
  int? _bufCount;

  /// Upload frames kept in flight: one fewer than mcumgr's buffers, since its
  /// answers come out of the same pool. 2 when it did not say (Zephyr's
  /// default is 4); a frame that finds no buffer is resent anyway.
  int get uploadWindow => ((_bufCount ?? 3) - 1).clamp(1, 4);

  /// [SmpDfuManager.uploadImage], with [uploadWindow] frames in flight.
  Future<void> uploadImage(Uint8List data, {void Function(double progress)? onProgress}) {
    onLog?.call("Upload: ${data.length} bytes in ${smpChunkSize(mtu)}-byte chunks, $uploadWindow in flight");
    return pipelinedUpload(
      data,
      chunkSize: smpChunkSize(mtu),
      window: uploadWindow,
      send: (payload) => sendRequest(SmpOp.write, SmpGroup.image, SmpImageCmd.upload, payload),
      onProgress: onProgress,
      onLog: onLog,
    );
  }

  Future<void> connect() async {
    // On Android the core also asks for the largest MTU; the device answers
    // with what it can take. (It used to be lowered to 251 right after.)
    await device.connect();

    if (Platform.isAndroid) {
      // The default interval is 30–50 ms, and every chunk waits for its answer:
      // that, more than the MTU, is what held the upload to ~5 KB/s.
      try {
        await device.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high);
      } catch (e) {
        onLog?.call("Connection priority request failed: $e");
      }
    } else {
      // On Windows/iOS, we just read whatever the OS negotiated
      try {
        final currMtu = await device.mtu.first.timeout(const Duration(seconds: 1));
        onLog?.call("Negotiated MTU: $currMtu");
      } catch (_) {}
    }

    List<BluetoothService> services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() == smpServiceUuid.toLowerCase()) {
        for (final char in service.characteristics) {
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

    // MCUmgr params (OS group, command 6): how large a frame mcumgr takes.
    // Older firmware answers with an error or not at all; the cap stays 251.
    try {
      final params = await sendRequest(SmpOp.read, SmpGroup.defaultGroup, 6, {}).timeout(const Duration(seconds: 3));
      final bufSize = params['buf_size'];
      if (bufSize is int && bufSize > 0) _bufSize = bufSize;
      final bufCount = params['buf_count'];
      if (bufCount is int && bufCount > 0) _bufCount = bufCount;
    } catch (e) {
      onLog?.call("MCUmgr params unavailable: $e");
    }
    onLog?.call("MTU ${device.mtuNow}, mcumgr buffers $_bufCount x $_bufSize -> frames up to ${mtu - 4} bytes");

    // Monitor for disconnection
    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _handleDisconnection();
      }
    });
  }

  void _handleDisconnection() {
    onLog?.call("SmpManager: Device disconnected. Clearing ${_pendingRequests.length} pending requests.");
    for (final completer in _pendingRequests.values) {
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
          final responseMap = decoded.toObject()! as Map;
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
        for (final entry in value.entries) _toCbor(entry.key): _toCbor(entry.value),
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

    // A frame that fits one ATT packet goes without response, as mcumgr's
    // characteristic is meant to be written: a write request costs a round
    // trip on top of the SMP answer. Larger ones need a long write.
    try {
      if (packet.length <= device.mtuNow - 3 && _smpCharacteristic!.properties.writeWithoutResponse) {
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
        // The sequence wraps every 256 frames; by now it may be a newer one's.
        if (identical(_pendingRequests[seq], completer)) _pendingRequests.remove(seq);
        throw TimeoutException("SMP Response timeout (seq: $seq)");
      },
    );
  }
}

/// Writes [data] to the secondary slot with up to [window] upload frames in
/// flight instead of one. Where the app cannot shorten the connection interval
/// (macOS, Windows) the wait for each answer, not the MTU, is what limits the
/// speed: one frame per round trip of two connection events.
///
/// mcumgr answers each frame with the offset it expects next, and drops a
/// frame that does not start there or finds no free buffer (unanswered). An
/// answer short of its frame's end means a frame was lost, and every frame
/// sent after it is dropped as out of place, so sending restarts from the
/// offset the device gave.
Future<void> pipelinedUpload(
  Uint8List data, {
  required int chunkSize,
  required int window,
  required Future<Map<dynamic, dynamic>> Function(Map<String, Object> payload) send,
  void Function(double progress)? onProgress,
  void Function(String message)? onLog,
  int maxRetries = 5,
}) async {
  // Answers, or the errors that stand for them, in the order they arrive.
  final answers = StreamController<({int epoch, int end, Object answer})>();
  final arrived = StreamIterator(answers.stream);
  var epoch = 0; // bumped on each restart: answers to older frames are stale
  var next = 0; // where the next frame starts
  var acked = 0; // what the device has taken
  var inFlight = 0; // frames of this epoch not yet answered
  var retries = 0;
  try {
    while (acked < data.length) {
      // The first frame goes alone: the device may erase the slot on it, and
      // frames queued behind that would find no buffer.
      while (inFlight < (acked == 0 ? 1 : window) && next < data.length) {
        final end = math.min(next + chunkSize, data.length);
        final payload = <String, Object>{'data': Uint8List.sublistView(data, next, end), 'off': next};
        if (next == 0) payload['len'] = data.length;
        final sentIn = epoch;
        inFlight++;
        send(payload).then<Object>((a) => a, onError: (Object e) => e).then((a) {
          if (!answers.isClosed) answers.add((epoch: sentIn, end: end, answer: a));
        });
        next = end;
      }

      await arrived.moveNext();
      final (epoch: sentIn, :end, :answer) = arrived.current;
      if (sentIn != epoch) continue;
      inFlight--;
      final rc = answer is Map ? answer['rc'] : null;
      final off = answer is Map ? answer['off'] : null;
      final refused = rc is int && rc != 0;
      if (!refused && off == end) {
        acked = end;
        retries = 0;
        onProgress?.call(acked / data.length);
        continue;
      }

      // Lost, out of place, refused or timed out: start over from where the
      // device is. Only a restart that gains nothing counts against the retries.
      final restart = !refused && off is int && off >= 0 && off <= data.length ? off : acked;
      if (restart <= acked && ++retries > maxRetries) {
        throw StateError(refused
            ? 'Upload refused at offset $acked (rc $rc)'
            : 'Upload stuck at offset $acked of ${data.length}: $answer');
      }
      onLog?.call('Upload: resending from $restart (frame to $end answered $answer)');
      if (restart > acked) retries = 0;
      epoch++;
      inFlight = 0;
      acked = next = restart;
      if (refused) await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  } finally {
    // Stale answers may still come in; they are dropped.
    await arrived.cancel();
    await answers.close();
  }
}

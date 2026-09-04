import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

/// Implements the core's [DfuDevice] with flutter_blue_plus.
class FbpDevice implements DfuDevice {
  FbpDevice(this.device);

  final BluetoothDevice device;

  @override
  String get id => device.remoteId.str;

  @override
  Future<void> connect({Duration? timeout}) => device.connect(
        license: License.nonprofit,
        timeout: timeout ?? const Duration(seconds: 15),
      );

  @override
  Future<void> disconnect() => device.disconnect();

  @override
  Future<List<DfuCharacteristic>> discoverCharacteristics() async {
    final services = await device.discoverServices();
    return [
      for (final service in services)
        for (final characteristic in service.characteristics)
          FbpCharacteristic(characteristic),
    ];
  }

  // Two wrappers around one device must compare equal, or a Set of them
  // collects duplicates of the same radio.
  @override
  bool operator ==(Object other) =>
      other is FbpDevice && other.device.remoteId == device.remoteId;

  @override
  int get hashCode => device.remoteId.hashCode;
}

/// Implements the core's [DfuCharacteristic] with flutter_blue_plus.
class FbpCharacteristic implements DfuCharacteristic {
  FbpCharacteristic(this.characteristic);

  final BluetoothCharacteristic characteristic;

  @override
  String get uuid => characteristic.uuid.toString();

  @override
  int get mtu => characteristic.device.mtuNow;

  @override
  Stream<List<int>> get values => characteristic.lastValueStream;

  @override
  Future<void> write(List<int> value, {bool withoutResponse = false}) =>
      characteristic.write(value, withoutResponse: withoutResponse);

  @override
  Future<void> setNotify(bool enable) =>
      characteristic.setNotifyValue(enable);
}

/// Presents a core [DfuListenable] as something Flutter can rebuild on.
///
/// The core cannot extend ChangeNotifier without importing Flutter, and
/// ListenableBuilder will not take anything that merely has the same two
/// methods, so this is the adapter between them. Wrappers are cached, because
/// a new one on every build would subscribe again on every frame.
Listenable listenableOf(DfuListenable source) =>
    _bridges.putIfAbsent(source, () => _ListenableBridge(source));

final _bridges = <DfuListenable, _ListenableBridge>{};

class _ListenableBridge extends ChangeNotifier {
  _ListenableBridge(this.source) {
    source.addListener(notifyListeners);
  }

  final DfuListenable source;

  @override
  void dispose() {
    source.removeListener(notifyListeners);
    super.dispose();
  }
}

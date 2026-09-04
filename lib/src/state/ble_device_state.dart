import '../ble.dart';
import 'notifier.dart';

class BleDeviceState extends DfuListenable {
  DfuDevice? device;
  DfuCharacteristic? controlPoint;
  DfuCharacteristic? dataPoint;
  bool isConnected = false;
  bool isTimeout = false;

  void update({
    DfuDevice? device,
    DfuCharacteristic? controlPoint,
    DfuCharacteristic? dataPoint,
    bool? isConnected,
    bool? isTimeout,
  }) {
    this.device = device ?? this.device;
    this.controlPoint = controlPoint ?? this.controlPoint;
    this.dataPoint = dataPoint ?? this.dataPoint;
    this.isConnected = isConnected ?? this.isConnected;
    this.isTimeout = isTimeout ?? this.isTimeout;
    notifyListeners();
  }

  void reset() {
    device?.disconnect();
    device = null;
    controlPoint = null;
    dataPoint = null;
    isConnected = false;
    isTimeout = false;
    notifyListeners();
  }
}

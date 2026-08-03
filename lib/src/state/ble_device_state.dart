import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDeviceState extends ChangeNotifier {
  BluetoothDevice? device;
  BluetoothCharacteristic? controlPoint;
  BluetoothCharacteristic? dataPoint;
  bool isConnected = false;
  bool isTimeout = false;

  void update({
    BluetoothDevice? device,
    BluetoothCharacteristic? controlPoint,
    BluetoothCharacteristic? dataPoint,
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

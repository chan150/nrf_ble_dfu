import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:mobx/mobx.dart';

part 'ble_device_state.g.dart';

class BleDeviceState = BleDeviceStateBase with _$BleDeviceState;

abstract class BleDeviceStateBase with Store {
  @observable
  BluetoothDevice? device;

  @observable
  BluetoothCharacteristic? controlPoint;

  @observable
  BluetoothCharacteristic? dataPoint;

  @observable
  bool isConnected = false;

  @observable
  bool isTimeout = false;

  @action
  void reset() {
    device?.disconnect();
    device = null;
    controlPoint = null;
    isConnected = false;
    isTimeout = false;
  }
}

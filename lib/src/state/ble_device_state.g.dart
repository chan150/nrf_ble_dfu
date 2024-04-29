// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ble_device_state.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$BleDeviceState on BleDeviceStateBase, Store {
  late final _$deviceAtom =
      Atom(name: 'BleDeviceStateBase.device', context: context);

  @override
  BluetoothDevice? get device {
    _$deviceAtom.reportRead();
    return super.device;
  }

  @override
  set device(BluetoothDevice? value) {
    _$deviceAtom.reportWrite(value, super.device, () {
      super.device = value;
    });
  }

  late final _$controlPointAtom =
      Atom(name: 'BleDeviceStateBase.controlPoint', context: context);

  @override
  BluetoothCharacteristic? get controlPoint {
    _$controlPointAtom.reportRead();
    return super.controlPoint;
  }

  @override
  set controlPoint(BluetoothCharacteristic? value) {
    _$controlPointAtom.reportWrite(value, super.controlPoint, () {
      super.controlPoint = value;
    });
  }

  late final _$dataPointAtom =
      Atom(name: 'BleDeviceStateBase.dataPoint', context: context);

  @override
  BluetoothCharacteristic? get dataPoint {
    _$dataPointAtom.reportRead();
    return super.dataPoint;
  }

  @override
  set dataPoint(BluetoothCharacteristic? value) {
    _$dataPointAtom.reportWrite(value, super.dataPoint, () {
      super.dataPoint = value;
    });
  }

  late final _$isConnectedAtom =
      Atom(name: 'BleDeviceStateBase.isConnected', context: context);

  @override
  bool get isConnected {
    _$isConnectedAtom.reportRead();
    return super.isConnected;
  }

  @override
  set isConnected(bool value) {
    _$isConnectedAtom.reportWrite(value, super.isConnected, () {
      super.isConnected = value;
    });
  }

  late final _$isTimeoutAtom =
      Atom(name: 'BleDeviceStateBase.isTimeout', context: context);

  @override
  bool get isTimeout {
    _$isTimeoutAtom.reportRead();
    return super.isTimeout;
  }

  @override
  set isTimeout(bool value) {
    _$isTimeoutAtom.reportWrite(value, super.isTimeout, () {
      super.isTimeout = value;
    });
  }

  late final _$BleDeviceStateBaseActionController =
      ActionController(name: 'BleDeviceStateBase', context: context);

  @override
  void reset() {
    final _$actionInfo = _$BleDeviceStateBaseActionController.startAction(
        name: 'BleDeviceStateBase.reset');
    try {
      return super.reset();
    } finally {
      _$BleDeviceStateBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
device: ${device},
controlPoint: ${controlPoint},
dataPoint: ${dataPoint},
isConnected: ${isConnected},
isTimeout: ${isTimeout}
    ''';
  }
}

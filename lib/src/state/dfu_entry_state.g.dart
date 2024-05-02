// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dfu_entry_state.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$DfuEntryState on DfuEntryStateBase, Store {
  late final _$entryPacketAtom =
      Atom(name: 'DfuEntryStateBase.entryPacket', context: context);

  @override
  ObservableList<int> get entryPacket {
    _$entryPacketAtom.reportRead();
    return super.entryPacket;
  }

  @override
  set entryPacket(ObservableList<int> value) {
    _$entryPacketAtom.reportWrite(value, super.entryPacket, () {
      super.entryPacket = value;
    });
  }

  late final _$entryControlPointAtom =
      Atom(name: 'DfuEntryStateBase.entryControlPoint', context: context);

  @override
  String get entryControlPoint {
    _$entryControlPointAtom.reportRead();
    return super.entryControlPoint;
  }

  @override
  set entryControlPoint(String value) {
    _$entryControlPointAtom.reportWrite(value, super.entryControlPoint, () {
      super.entryControlPoint = value;
    });
  }

  late final _$dfuControlPointAtom =
      Atom(name: 'DfuEntryStateBase.dfuControlPoint', context: context);

  @override
  String get dfuControlPoint {
    _$dfuControlPointAtom.reportRead();
    return super.dfuControlPoint;
  }

  @override
  set dfuControlPoint(String value) {
    _$dfuControlPointAtom.reportWrite(value, super.dfuControlPoint, () {
      super.dfuControlPoint = value;
    });
  }

  late final _$dfuDataPointAtom =
      Atom(name: 'DfuEntryStateBase.dfuDataPoint', context: context);

  @override
  String get dfuDataPoint {
    _$dfuDataPointAtom.reportRead();
    return super.dfuDataPoint;
  }

  @override
  set dfuDataPoint(String value) {
    _$dfuDataPointAtom.reportWrite(value, super.dfuDataPoint, () {
      super.dfuDataPoint = value;
    });
  }

  late final _$autoDfuTargetsAtom =
      Atom(name: 'DfuEntryStateBase.autoDfuTargets', context: context);

  @override
  ObservableList<BluetoothDevice> get autoDfuTargets {
    _$autoDfuTargetsAtom.reportRead();
    return super.autoDfuTargets;
  }

  @override
  set autoDfuTargets(ObservableList<BluetoothDevice> value) {
    _$autoDfuTargetsAtom.reportWrite(value, super.autoDfuTargets, () {
      super.autoDfuTargets = value;
    });
  }

  late final _$enableDfuEntryProcessAtom =
      Atom(name: 'DfuEntryStateBase.enableDfuEntryProcess', context: context);

  @override
  bool get enableDfuEntryProcess {
    _$enableDfuEntryProcessAtom.reportRead();
    return super.enableDfuEntryProcess;
  }

  @override
  set enableDfuEntryProcess(bool value) {
    _$enableDfuEntryProcessAtom.reportWrite(value, super.enableDfuEntryProcess,
        () {
      super.enableDfuEntryProcess = value;
    });
  }

  late final _$enableDfuProcessAtom =
      Atom(name: 'DfuEntryStateBase.enableDfuProcess', context: context);

  @override
  bool get enableDfuProcess {
    _$enableDfuProcessAtom.reportRead();
    return super.enableDfuProcess;
  }

  @override
  set enableDfuProcess(bool value) {
    _$enableDfuProcessAtom.reportWrite(value, super.enableDfuProcess, () {
      super.enableDfuProcess = value;
    });
  }

  late final _$autoEntryDeviceNameAtom =
      Atom(name: 'DfuEntryStateBase.autoEntryDeviceName', context: context);

  @override
  String get autoEntryDeviceName {
    _$autoEntryDeviceNameAtom.reportRead();
    return super.autoEntryDeviceName;
  }

  @override
  set autoEntryDeviceName(String value) {
    _$autoEntryDeviceNameAtom.reportWrite(value, super.autoEntryDeviceName, () {
      super.autoEntryDeviceName = value;
    });
  }

  late final _$autoDfuDeviceNameAtom =
      Atom(name: 'DfuEntryStateBase.autoDfuDeviceName', context: context);

  @override
  String get autoDfuDeviceName {
    _$autoDfuDeviceNameAtom.reportRead();
    return super.autoDfuDeviceName;
  }

  @override
  set autoDfuDeviceName(String value) {
    _$autoDfuDeviceNameAtom.reportWrite(value, super.autoDfuDeviceName, () {
      super.autoDfuDeviceName = value;
    });
  }

  @override
  String toString() {
    return '''
entryPacket: ${entryPacket},
entryControlPoint: ${entryControlPoint},
dfuControlPoint: ${dfuControlPoint},
dfuDataPoint: ${dfuDataPoint},
autoDfuTargets: ${autoDfuTargets},
enableDfuEntryProcess: ${enableDfuEntryProcess},
enableDfuProcess: ${enableDfuProcess},
autoEntryDeviceName: ${autoEntryDeviceName},
autoDfuDeviceName: ${autoDfuDeviceName}
    ''';
  }
}

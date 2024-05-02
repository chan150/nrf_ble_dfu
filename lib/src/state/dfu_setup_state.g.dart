// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dfu_setup_state.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$DfuSetupState on DfuSetupStateBase, Store {
  late final _$entryPacketAtom =
      Atom(name: 'DfuSetupStateBase.entryPacket', context: context);

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
      Atom(name: 'DfuSetupStateBase.entryControlPoint', context: context);

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
      Atom(name: 'DfuSetupStateBase.dfuControlPoint', context: context);

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
      Atom(name: 'DfuSetupStateBase.dfuDataPoint', context: context);

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
      Atom(name: 'DfuSetupStateBase.autoDfuTargets', context: context);

  @override
  ObservableSet<BluetoothDevice> get autoDfuTargets {
    _$autoDfuTargetsAtom.reportRead();
    return super.autoDfuTargets;
  }

  @override
  set autoDfuTargets(ObservableSet<BluetoothDevice> value) {
    _$autoDfuTargetsAtom.reportWrite(value, super.autoDfuTargets, () {
      super.autoDfuTargets = value;
    });
  }

  late final _$autoDfuFinishedAtom =
      Atom(name: 'DfuSetupStateBase.autoDfuFinished', context: context);

  @override
  ObservableSet<BluetoothDevice> get autoDfuFinished {
    _$autoDfuFinishedAtom.reportRead();
    return super.autoDfuFinished;
  }

  @override
  set autoDfuFinished(ObservableSet<BluetoothDevice> value) {
    _$autoDfuFinishedAtom.reportWrite(value, super.autoDfuFinished, () {
      super.autoDfuFinished = value;
    });
  }

  late final _$enableTargetEntryProcessAtom = Atom(
      name: 'DfuSetupStateBase.enableTargetEntryProcess', context: context);

  @override
  bool get enableTargetEntryProcess {
    _$enableTargetEntryProcessAtom.reportRead();
    return super.enableTargetEntryProcess;
  }

  @override
  set enableTargetEntryProcess(bool value) {
    _$enableTargetEntryProcessAtom
        .reportWrite(value, super.enableTargetEntryProcess, () {
      super.enableTargetEntryProcess = value;
    });
  }

  late final _$enableAutoEntryProcessAtom =
      Atom(name: 'DfuSetupStateBase.enableAutoEntryProcess', context: context);

  @override
  bool get enableAutoEntryProcess {
    _$enableAutoEntryProcessAtom.reportRead();
    return super.enableAutoEntryProcess;
  }

  @override
  set enableAutoEntryProcess(bool value) {
    _$enableAutoEntryProcessAtom
        .reportWrite(value, super.enableAutoEntryProcess, () {
      super.enableAutoEntryProcess = value;
    });
  }

  late final _$enableAutoDfuProcessAtom =
      Atom(name: 'DfuSetupStateBase.enableAutoDfuProcess', context: context);

  @override
  bool get enableAutoDfuProcess {
    _$enableAutoDfuProcessAtom.reportRead();
    return super.enableAutoDfuProcess;
  }

  @override
  set enableAutoDfuProcess(bool value) {
    _$enableAutoDfuProcessAtom.reportWrite(value, super.enableAutoDfuProcess,
        () {
      super.enableAutoDfuProcess = value;
    });
  }

  late final _$autoEntryDeviceNameAtom =
      Atom(name: 'DfuSetupStateBase.autoEntryDeviceName', context: context);

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
      Atom(name: 'DfuSetupStateBase.autoDfuDeviceName', context: context);

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
autoDfuFinished: ${autoDfuFinished},
enableTargetEntryProcess: ${enableTargetEntryProcess},
enableAutoEntryProcess: ${enableAutoEntryProcess},
enableAutoDfuProcess: ${enableAutoDfuProcess},
autoEntryDeviceName: ${autoEntryDeviceName},
autoDfuDeviceName: ${autoDfuDeviceName}
    ''';
  }
}

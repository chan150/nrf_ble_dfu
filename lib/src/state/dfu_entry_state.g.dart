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
  ObservableList<String> get autoDfuTargets {
    _$autoDfuTargetsAtom.reportRead();
    return super.autoDfuTargets;
  }

  @override
  set autoDfuTargets(ObservableList<String> value) {
    _$autoDfuTargetsAtom.reportWrite(value, super.autoDfuTargets, () {
      super.autoDfuTargets = value;
    });
  }

  @override
  String toString() {
    return '''
entryPacket: ${entryPacket},
entryControlPoint: ${entryControlPoint},
dfuControlPoint: ${dfuControlPoint},
dfuDataPoint: ${dfuDataPoint},
autoDfuTargets: ${autoDfuTargets}
    ''';
  }
}

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
  ObservableList<dynamic> get entryPacket {
    _$entryPacketAtom.reportRead();
    return super.entryPacket;
  }

  @override
  set entryPacket(ObservableList<dynamic> value) {
    _$entryPacketAtom.reportWrite(value, super.entryPacket, () {
      super.entryPacket = value;
    });
  }

  @override
  String toString() {
    return '''
entryPacket: ${entryPacket}
    ''';
  }
}

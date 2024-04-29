// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dfu_file_state.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$DfuFileState on DfuFileStateBase, Store {
  late final _$pathAtom = Atom(name: 'DfuFileStateBase.path', context: context);

  @override
  String? get path {
    _$pathAtom.reportRead();
    return super.path;
  }

  @override
  set path(String? value) {
    _$pathAtom.reportWrite(value, super.path, () {
      super.path = value;
    });
  }

  late final _$outputPathAtom =
      Atom(name: 'DfuFileStateBase.outputPath', context: context);

  @override
  String? get outputPath {
    _$outputPathAtom.reportRead();
    return super.outputPath;
  }

  @override
  set outputPath(String? value) {
    _$outputPathAtom.reportWrite(value, super.outputPath, () {
      super.outputPath = value;
    });
  }

  late final _$binPathAtom =
      Atom(name: 'DfuFileStateBase.binPath', context: context);

  @override
  String? get binPath {
    _$binPathAtom.reportRead();
    return super.binPath;
  }

  @override
  set binPath(String? value) {
    _$binPathAtom.reportWrite(value, super.binPath, () {
      super.binPath = value;
    });
  }

  late final _$datPathAtom =
      Atom(name: 'DfuFileStateBase.datPath', context: context);

  @override
  String? get datPath {
    _$datPathAtom.reportRead();
    return super.datPath;
  }

  @override
  set datPath(String? value) {
    _$datPathAtom.reportWrite(value, super.datPath, () {
      super.datPath = value;
    });
  }

  @override
  String toString() {
    return '''
path: ${path},
outputPath: ${outputPath},
binPath: ${binPath},
datPath: ${datPath}
    ''';
  }
}

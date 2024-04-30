// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dfu_progress_state.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$DfuProgressState on DfuProgressStateBase, Store {
  late final _$fileSizeAtom =
      Atom(name: 'DfuProgressStateBase.fileSize', context: context);

  @override
  int? get fileSize {
    _$fileSizeAtom.reportRead();
    return super.fileSize;
  }

  @override
  set fileSize(int? value) {
    _$fileSizeAtom.reportWrite(value, super.fileSize, () {
      super.fileSize = value;
    });
  }

  late final _$completedSizeAtom =
      Atom(name: 'DfuProgressStateBase.completedSize', context: context);

  @override
  int? get completedSize {
    _$completedSizeAtom.reportRead();
    return super.completedSize;
  }

  @override
  set completedSize(int? value) {
    _$completedSizeAtom.reportWrite(value, super.completedSize, () {
      super.completedSize = value;
    });
  }

  @override
  String toString() {
    return '''
fileSize: ${fileSize},
completedSize: ${completedSize}
    ''';
  }
}

import 'package:mobx/mobx.dart';

part 'dfu_file_state.g.dart';

class DfuFileState = DfuFileStateBase with _$DfuFileState;

abstract class DfuFileStateBase with Store {
  @observable
  String? path;

  @observable
  String? outputPath;

  @observable
  String? binPath;

  @observable
  String? datPath;
}

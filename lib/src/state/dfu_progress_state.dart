import 'package:mobx/mobx.dart';

part 'dfu_progress_state.g.dart';

class DfuProgressState = DfuProgressStateBase with _$DfuProgressState;

abstract class DfuProgressStateBase with Store {
  @observable
  int? fileSize;

  @observable
  int? completedSize;
}

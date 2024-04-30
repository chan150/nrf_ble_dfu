import 'package:mobx/mobx.dart';

part 'dfu_entry_state.g.dart';

class DfuEntryState = DfuEntryStateBase with _$DfuEntryState;

abstract class DfuEntryStateBase with Store {
  @observable
  ObservableList entryPacket = ObservableList<int>.of([0xBB, 0xCC, 0x01, 0xFA]);
}
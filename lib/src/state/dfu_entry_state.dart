import 'package:mobx/mobx.dart';

part 'dfu_entry_state.g.dart';

class DfuEntryState = DfuEntryStateBase with _$DfuEntryState;

abstract class DfuEntryStateBase with Store {
  @observable
  ObservableList entryPacket = ObservableList<int>.of([0xBB, 0xCC, 0x01, 0xFA]);

  @observable
  String entryControlPoint = '2CF0';

  @observable
  String controlPoint = '8ec90001-f315-4f60-9fb8-838830daea50';

  @observable
  String dataPoint = '8ec90002-f315-4f60-9fb8-838830daea50';
}
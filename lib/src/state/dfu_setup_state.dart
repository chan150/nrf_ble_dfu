import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:mobx/mobx.dart';

part 'dfu_setup_state.g.dart';

class DfuSetupState = DfuSetupStateBase with _$DfuSetupState;

abstract class DfuSetupStateBase with Store {
  @observable
  ObservableList<int> entryPacket = ObservableList.of([0xBB, 0xCC, 0x01, 0xFA]);

  @observable
  String entryControlPoint = '2CF0';

  @observable
  String dfuControlPoint = '8ec90001-f315-4f60-9fb8-838830daea50';

  @observable
  String dfuDataPoint = '8ec90002-f315-4f60-9fb8-838830daea50';

  @observable
  ObservableList<BluetoothDevice> autoDfuTargets = ObservableList();

  @observable
  bool enableDfuEntryProcess = true;

  @observable
  bool enableDfuProcess = true;

  @observable
  String autoEntryDeviceName = '';

  @observable
  String autoDfuDeviceName = '';
}

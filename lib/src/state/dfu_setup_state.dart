import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mobx/mobx.dart';
import 'dfu_history_entry.dart';
import '../database/log_entry.dart';

part 'dfu_setup_state.g.dart';

class DfuSetupState = DfuSetupStateBase with _$DfuSetupState;

abstract class DfuSetupStateBase with Store {
  @observable
  ObservableList<int> entryPacket = ObservableList.of([0x4E, 0x45, 0x01, 0xFA]);

  @observable
  String entryControlPoint = '00002cf0-0000-1000-8000-00805f9b34fb';

  @observable
  String dfuControlPoint = '8ec90001-f315-4f60-9fb8-838830daea50';

  @observable
  String dfuDataPoint = '8ec90002-f315-4f60-9fb8-838830daea50';

  @observable
  ObservableSet<BluetoothDevice> autoDfuTargets = ObservableSet();

  @observable
  ObservableSet<BluetoothDevice> autoDfuFinished = ObservableSet();

  @observable
  bool enableTargetEntryProcess = true;

  @observable
  bool enableAutoEntryProcess = true;

  @observable
  bool enableAutoDfuProcess = true;

  @observable
  String autoEntryDeviceName = 'NLBD';

  @observable
  String autoDfuDeviceName = 'NEUL_DFU';

  @observable
  ObservableList<DfuHistoryEntry> history = ObservableList();

  @observable
  ObservableList<LogEntry> logs = ObservableList();

  @observable
  int maxLogs = 200;

  @observable
  ObservableSet<String> updatedMacs = ObservableSet();

  @observable
  bool isAutoScanEnabled = false;

  @observable
  bool isAutoUpdateEnabled = false;
}

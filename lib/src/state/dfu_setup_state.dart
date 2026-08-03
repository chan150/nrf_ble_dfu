import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dfu_history_entry.dart';
import 'log_entry.dart';

class DfuSetupState extends ChangeNotifier {
  List<int> entryPacket = [0x4E, 0x45, 0x01, 0xFA];
  String entryControlPoint = '00002cf0-0000-1000-8000-00805f9b34fb';
  String dfuControlPoint = '8ec90001-f315-4f60-9fb8-838830daea50';
  String dfuDataPoint = '8ec90002-f315-4f60-9fb8-838830daea50';

  Set<BluetoothDevice> autoDfuTargets = {};
  Set<BluetoothDevice> autoDfuFinished = {};

  bool enableTargetEntryProcess = true;
  bool enableAutoEntryProcess = true;
  bool enableAutoDfuProcess = true;

  String autoEntryDeviceName = 'NEUL';
  String autoDfuDeviceName = 'NEUL_DFU';

  List<DfuHistoryEntry> history = [];
  List<LogEntry> logs = [];
  int maxLogs = 200;

  Set<String> updatedMacs = {};

  bool isAutoScanEnabled = false;
  bool isAutoUpdateEnabled = false;

  List<DfuHistoryEntry> get successHistory =>
      history.where((e) => e.status == 'success').toList();

  List<DfuHistoryEntry> get failureHistory =>
      history.where((e) => e.status == 'failed').toList();

  void notify() => notifyListeners();
}

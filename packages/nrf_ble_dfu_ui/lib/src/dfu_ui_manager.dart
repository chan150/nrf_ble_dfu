import 'dart:convert';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'database/dfu_database.dart';

class DfuUiManager {
  static final DfuUiManager _instance = DfuUiManager._internal();
  factory DfuUiManager() => _instance;
  DfuUiManager._internal();

  late final SharedPreferences _prefs;
  final SqfliteDfuDatabase _db = SqfliteDfuDatabase();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _db.initialize();

    // 1. Restore history and logs from SQLite
    final history = await _db.getHistory();
    final logs = await _db.getLogs();

    final setup = NrfBleDfu().setup;
    setup.history.clear();
    setup.history.addAll(history);
    setup.logs.clear();
    setup.logs.addAll(logs.reversed);
    setup.updatedMacs.clear();
    setup.updatedMacs.addAll(history.map((e) => e.remoteId));
    setup.notify();

    // 2. Restore presets from SharedPreferences
    final jsonStr = _prefs.getString('dfu_presets');
    if (jsonStr != null) {
      try {
        final container = DfuPresetsContainer.fromJson(jsonDecode(jsonStr));
        final dfu = NrfBleDfu();
        dfu.presets.clear();
        dfu.presets.addAll(container.presets);

        final last = container.lastUsed;
        if (last.isNotEmpty) {
          setup.entryControlPoint =
              last['entry_uuid'] ?? setup.entryControlPoint;
          final pkt = last['entry_pkt'] as String?;
          if (pkt != null) {
            setup.entryPacket.clear();
            setup.entryPacket.addAll(pkt.fromRawHex);
          }
          setup.autoDfuDeviceName =
              last['target_dfu_name'] ?? setup.autoDfuDeviceName;
          dfu.selectedPresetIndex = last['selected_index'] as int?;
        }
        setup.notify();

        // Recover firmware path if exists asynchronously
        final lastUsedMap = container.lastUsed;
        final fwPath = lastUsedMap['firmware_path'] as String?;
        if (fwPath != null && File(fwPath).existsSync()) {
          final tempDir = await getTemporaryDirectory();
          final bytes = File(fwPath).readAsBytesSync();
          await dfu.setFirmwareFile(fwPath, bytes, tempDir.path);
        }
      } catch (e) {
        NrfBleDfu().log('Error loading presets: $e');
      }
    }

    if (NrfBleDfu().presets.isEmpty) {
      NrfBleDfu().presets.add(DfuPreset(
            name: 'default',
            entryUuid: '00002cf0-0000-1000-8000-00805f9b34fb',
            entryPkt: '4E4501FA',
            targetName: 'NEUL',
            targetDfuName: 'NEUL_DFU',
          ));
      setup.notify();
      savePresets();
    }

    // 3. Listen to core events to persist logs and history
    NrfBleDfu().onLog.listen((entry) {
      _db.insertLog(entry);
    });

    NrfBleDfu().onHistory.listen((entry) {
      _db.insertHistory(entry);
    });

    NrfBleDfu().onHistoryDelete.listen((entry) {
      _db.deleteHistoryEntry(entry.remoteId, entry.timestamp.toIso8601String());
    });

    NrfBleDfu().onHistoryClear.listen((_) {
      _db.clearHistory();
    });

    // 4. Auto-save presets on setup changes
    NrfBleDfu().setup.addListener(savePresets);
  }

  void savePresets() {
    final dfu = NrfBleDfu();
    final container = DfuPresetsContainer(
      lastUsed: {
        'entry_uuid': dfu.entryControlPoint,
        'entry_pkt': dfu.entryPacket.rawHex,
        'target_name': dfu.autoEntryDeviceName,
        'target_dfu_name': dfu.autoDfuDeviceName,
        'selected_index': dfu.selectedPresetIndex,
        'firmware_path': dfu.file.path,
      },
      presets: dfu.presets,
    );
    _prefs.setString('dfu_presets', jsonEncode(container.toJson()));
  }

  void dispose() {
    NrfBleDfu().setup.removeListener(savePresets);
  }
}

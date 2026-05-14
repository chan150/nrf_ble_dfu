import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mobx/mobx.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'state/state.dart';
import 'enum/enum.dart';
import 'extension/extension.dart';
import 'database/dfu_database.dart';
import 'database/log_entry.dart';

export 'dart:async';
export 'dart:io';

class NrfBleDfu {
  factory NrfBleDfu() => _instance;

  static final _instance = NrfBleDfu._internal();

  NrfBleDfu._internal() {
    _init();
  }

  Future<void> _init() async {
    try {
      await initializeDatabase();
      await initializeSharedPreference();
    } catch (e) {
      log('Initialization error: $e', level: 'ERROR');
      // Ensure app still starts even if DB/Prefs fail
      await _done();
    }
  }

  Future<void> initializeDatabase() async {
    await DfuDatabase().database;
    final history = await DfuDatabase().getHistory();
    final logs = await DfuDatabase().getLogs();
    runInAction(() {
      setup.history.clear();
      setup.history.addAll(history);
      setup.logs.clear();
      setup.logs.addAll(logs.reversed);
      setup.updatedMacs.clear();
      setup.updatedMacs.addAll(history.map((e) => e.remoteId));
    });
  }

  late SharedPreferences prefs;
  final entry = BleDeviceState();
  final dfu = BleDeviceState();
  final file = DfuFileState();
  final setup = DfuSetupState();
  final progress = DfuProgressState();
  final presets = ObservableList<DfuPreset>();
  final selectedPresetIndex = Observable<int?>(null);
  final Map<String, DateTime> _failedCooldown = {};

  Future<void> initializeSharedPreference() async {
    prefs = await SharedPreferences.getInstance();

    // Load presets and last_used from JSON
    final jsonStr = prefs.getString('dfu_presets');
    if (jsonStr != null) {
      try {
        final container = DfuPresetsContainer.fromJson(jsonDecode(jsonStr));
        presets.clear();
        presets.addAll(container.presets);

        // Apply last_used if exists
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

          final fwPath = last['firmware_path'] as String?;
          if (fwPath != null && File(fwPath).existsSync()) {
            file.path = fwPath;
            final bytes = File(fwPath).readAsBytesSync();
            await extractZip(bytes);
          }
          runInAction(() {
            selectedPresetIndex.value = last['selected_index'] as int?;
          });
        }
      } catch (e) {
        log('Error loading presets: $e');
      }
    }

    if (presets.isEmpty) {
      presets.add(DfuPreset(
        name: 'default',
        entryUuid: '00002cf0-0000-1000-8000-00805f9b34fb',
        entryPkt: '4E4501FA',
        targetName: 'NLBD',
        targetDfuName: 'NEUL_DFU',
      ));
      savePresets();
    }

    loadHistory();

    await _done();
  }

  void loadHistory() {
    final jsonStr = prefs.getString('dfu_history');
    if (jsonStr != null) {
      try {
        final container = DfuHistoryContainer.fromJson(jsonDecode(jsonStr));
        runInAction(() {
          setup.history.clear();
          setup.history.addAll(container.history);
          setup.updatedMacs.clear();
          setup.updatedMacs.addAll(container.history
              .where((e) => e.status == 'success')
              .map((e) => e.remoteId));
        });
      } catch (e) {
        log('Error loading history: $e');
      }
    }
  }

  void saveHistory() {
    // Deprecated: history is now managed by SQLite
  }

  void addHistoryEntry(
      {required String remoteId,
      required String deviceName,
      required String status,
      String? note}) {
    runInAction(() {
      final entry = DfuHistoryEntry(
        remoteId: remoteId,
        deviceName: deviceName,
        timestamp: DateTime.now(),
        status: status,
        note: note,
      );
      setup.history.insert(0, entry);
      if (status == 'success') {
        setup.updatedMacs.add(remoteId);
      }
      DfuDatabase().insertHistory(entry);
    });
  }

  void log(String message, {String level = 'INFO'}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
    );
    runInAction(() {
      setup.logs.add(entry);
      if (setup.logs.length > setup.maxLogs) {
        setup.logs.removeAt(0);
      }
    });
    DfuDatabase().insertLog(entry);
  }

  void retryDfu(String remoteId) {
    runInAction(() {
      setup.updatedMacs.remove(remoteId);
      // Also remove from finished if it was there (for immediate UI feedback)
      setup.autoDfuFinished.removeWhere((d) => d.remoteId.str == remoteId);
      saveHistory();
    });
  }

  Future<void> clearHistory() async {
    await DfuDatabase().clearHistory();
    runInAction(() {
      setup.history.clear();
      setup.updatedMacs.clear();
      setup.autoDfuFinished.clear();
    });
    log('All history cleared.');
  }

  Future<void> waitForCompletion() async {
    await asyncWhen((_) => _completed.value == true);
    log('Completed $runtimeType');
  }

  late final _done = Action(() => _completed.value = true);
  final _completed = Observable(false);

  //////////////////////////////////////////

  String get entryControlPoint => setup.entryControlPoint;

  set entryControlPoint(String value) {
    runInAction(() {
      setup.entryControlPoint = value;
      selectedPresetIndex.value = null;
      savePresets();
    });
  }

  List<int> get entryPacket => setup.entryPacket;

  set entryPacket(List<int> value) {
    runInAction(() {
      setup.entryPacket.clear();
      setup.entryPacket.addAll(value);
      selectedPresetIndex.value = null;
      savePresets();
    });
  }

  String get autoEntryDeviceName => setup.autoEntryDeviceName;

  set autoEntryDeviceName(String value) {
    runInAction(() {
      setup.autoEntryDeviceName = value;
      selectedPresetIndex.value = null;
      savePresets();
    });
  }

  String get autoDfuDeviceName => setup.autoDfuDeviceName;

  set autoDfuDeviceName(String value) {
    runInAction(() {
      setup.autoDfuDeviceName = value;
      selectedPresetIndex.value = null;
      savePresets();
    });
  }

  //////////////////////////////////////////

  void savePresets() {
    final container = DfuPresetsContainer(
      lastUsed: {
        'entry_uuid': entryControlPoint,
        'entry_pkt': entryPacket.rawHex,
        'target_name': autoEntryDeviceName,
        'target_dfu_name': autoDfuDeviceName,
        'selected_index': selectedPresetIndex.value,
        'firmware_path': file.path,
      },
      presets: presets,
    );
    prefs.setString('dfu_presets', jsonEncode(container.toJson()));
  }

  void loadPreset(int index) {
    if (index < 0 || index >= presets.length) return;
    runInAction(() {
      final p = presets[index];
      setup.entryControlPoint = p.entryUuid;
      setup.entryPacket.clear();
      setup.entryPacket.addAll(p.entryPkt.fromRawHex);
      setup.autoEntryDeviceName = p.targetName;
      setup.autoDfuDeviceName = p.targetDfuName;
      selectedPresetIndex.value = index;
      savePresets();
    });
  }

  void updatePreset(int index) {
    if (index < 0 || index >= presets.length) return;
    runInAction(() {
      presets[index] = DfuPreset(
        name: presets[index].name,
        entryUuid: entryControlPoint,
        entryPkt: entryPacket.rawHex,
        targetName: autoEntryDeviceName,
        targetDfuName: autoDfuDeviceName,
      );
      savePresets();
    });
  }

  void renamePreset(int index, String name) {
    if (index < 0 || index >= presets.length) return;
    runInAction(() {
      final p = presets[index];
      presets[index] = DfuPreset(
        name: name,
        entryUuid: p.entryUuid,
        entryPkt: p.entryPkt,
        targetName: p.targetName,
        targetDfuName: p.targetDfuName,
      );
      savePresets();
    });
  }

  void addNewPreset(String name) {
    runInAction(() {
      presets.add(DfuPreset(
        name: name,
        entryUuid: entryControlPoint,
        entryPkt: entryPacket.rawHex,
        targetName: autoEntryDeviceName,
        targetDfuName: autoDfuDeviceName,
      ));
      selectedPresetIndex.value = presets.length - 1;
      savePresets();
    });
  }

  void deletePreset(int index) {
    if (index < 0 || index >= presets.length) return;
    if (presets.length <= 1) return; // Keep at least one
    runInAction(() {
      presets.removeAt(index);
      selectedPresetIndex.value = null;
      savePresets();
    });
  }

  //////////////////////////////////////////

  Future<void> selectDfu() async {
    final result = await fp.FilePicker.pickFiles();
    file.path = result?.paths.singleOrNull;
    if (file.path == null) return;
    savePresets();
    final bytes = File(file.path!).readAsBytesSync();
    await extractZip(bytes);
  }

  Future<void> extractZip(List<int> bytes) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = join(tempDir.path, "firmware_files");
    final outputDir = Directory(outputPath);
    await outputDir.create();
    if (!outputDir.existsSync()) return;
    file.outputPath = outputPath;

    await extractArchiveToDisk(ZipDecoder().decodeBytes(bytes), outputPath);

    final list = outputDir.listSync();
    file.datPath = list.where((e) => e.path.endsWith('dat')).singleOrNull?.path;
    file.binPath = list.where((e) => e.path.endsWith('bin')).singleOrNull?.path;
  }

  Future<void> _transferObject({
    required int type,
    required Uint8List buffer,
    required BluetoothCharacteristic controlPoint,
    required BluetoothCharacteristic dataPoint,
  }) async {
    late int maxSize;
    late int offset;
    late int crc;

    ///
    late int from;
    late int to;
    late List<int> data;

    bool isPrepared = false;
    bool isSelectCommand = true;
    int step = 0;

    progress.fileSize = null;
    progress.completedSize = null;

    /// https://infocenter.nordicsemi.com/index.jsp?topic=%2Fsdk_nrf5_v17.0.2%2Flib_bootloader_dfu_process.html
    await for (final event in controlPoint.lastValueStream) {
      if (event.elementAtOrNull(0) == NrfDfuOp.response.code) {
        log(event.hexString);
      }

      /// select command
      /// [06 01]
      if (isSelectCommand) {
        isSelectCommand = false;
        await controlPoint.write([NrfDfuOp.objectSelect.code, type]);
        continue;
      }

      if (event.elementAtOrNull(0) != NrfDfuOp.response.code) {
        log('Not response packet: $event');
        continue;
      }

      /// response select success: max_size offset CRC32
      /// [60 06 01 XXXXXXXX XXXXXXXX XXXXXXXX]
      if (event.elementAtOrNull(0) == NrfDfuOp.response.code &&
          event.elementAtOrNull(1) == NrfDfuOp.objectSelect.code &&
          event.elementAtOrNull(2) == NrfDfuResult.success.code) {
        maxSize = event.getInt32(3);
        offset = event.getInt32(7);
        crc = event.getInt32(11);

        from = step * maxSize;
        to = math.min((step + 1) * maxSize, buffer.length);
        data = buffer.sublist(from, to);

        /// notify progress
        progress.fileSize ??= buffer.length;
        progress.completedSize ??= 0;

        // final checkSize = offset == dat.length;
        // final checkCrc = crc == crc32(dat);
        // if(checkInit && checkSize && checkCrc){
        //   log('Init packet already received');
        // }

        final sizePacket = data.length.toBytes;
        await controlPoint
            .write([NrfDfuOp.objectCreate.code, type, ...sizePacket]);
        continue;
      }

      /// Response Create Success
      /// [60 01 01]
      if (event.elementAtOrNull(0) == NrfDfuOp.response.code &&
          event.elementAtOrNull(1) == NrfDfuOp.objectCreate.code &&
          event.elementAtOrNull(2) == NrfDfuResult.success.code) {
        from = step * maxSize;
        to = math.min((step + 1) * maxSize, buffer.length);
        data = buffer.sublist(from, to);
        for (var i = 0; i < data.length / 20; i++) {
          final packet =
              data.sublist(i * 20, math.min((i + 1) * 20, data.length));
          await dataPoint.write(packet, withoutResponse: true);
        }
        await controlPoint.write([NrfDfuOp.crcGet.code]);
        isPrepared = true;
        continue;
      }

      /// Response PRN Success: offset CRC32
      /// [60 03 01 XXXXXXXX XXXXXXXX]
      if (event.elementAtOrNull(0) == NrfDfuOp.response.code &&
          event.elementAtOrNull(1) == NrfDfuOp.crcGet.code &&
          event.elementAtOrNull(2) == NrfDfuResult.success.code) {
        offset = event.getInt32(3);
        crc = event.getInt32(7);

        // TODO: should validate CRC32 function
        log((_crc32(buffer.sublist(0, offset)), offset, crc).toString());

        if (isPrepared) {
          await controlPoint.write([NrfDfuOp.objectExecute.code]);
        }
        isPrepared = false;
        continue;
      }

      /// Response Execute Success
      /// [60 04 01]
      if (event.elementAtOrNull(0) == NrfDfuOp.response.code &&
          event.elementAtOrNull(1) == NrfDfuOp.objectExecute.code &&
          event.elementAtOrNull(2) == NrfDfuResult.success.code) {
        final current = progress.completedSize ?? 0;
        progress.completedSize = current + data.length;

        if (step + 1 < buffer.length / maxSize) {
          await controlPoint.write([NrfDfuOp.objectSelect.code, type]);
          step++;
          continue;
        } else {
          break;
        }
      }

      throw Exception('Unhandled packet: $event');
    }
  }

  int _crc32(List<int> buffer) {
    const crc32Poly = 0xEDB88320;
    int crc = 0xFFFFFFFF;
    for (int i = 0; i < buffer.length; i++) {
      crc ^= buffer[i];
      for (int j = 0; j < 8; j++) {
        if ((crc & 1) == 1) {
          crc = (crc >> 1) ^ crc32Poly;
        } else {
          crc >>= 1;
        }
      }
    }
    return ~crc;
  }

  Future<void> updateFirmware(BluetoothDevice device) async {
    final datPath = file.datPath;
    final binPath = file.binPath;
    if (datPath == null || binPath == null) {
      log("Error: Missing dat or bin file");
      return;
    }
    final dat = File(datPath).readAsBytesSync();
    final bin = File(binPath).readAsBytesSync();

    final services = await device.discoverServices();

    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.characteristicUuid == Guid.fromString(setup.dfuControlPoint)) {
          dfu.controlPoint = c;
        }
        if (c.characteristicUuid == Guid.fromString(setup.dfuDataPoint)) {
          dfu.dataPoint = c;
        }
      }
    }

    final controlPoint = dfu.controlPoint;
    final dataPoint = dfu.dataPoint;

    if (controlPoint == null) throw Exception('Control point not found');
    if (dataPoint == null) throw Exception('Data point not found');

    await controlPoint.setNotifyValue(true);

    /// transfer init packet
    try {
      await _transferObject(
        type: NrfDfuTransferType.init.code,
        buffer: dat,
        controlPoint: controlPoint,
        dataPoint: dataPoint,
      );
    } catch (_) {
      await Future.delayed(const Duration(seconds: 1));
      await _transferObject(
        type: NrfDfuTransferType.init.code,
        buffer: dat,
        controlPoint: controlPoint,
        dataPoint: dataPoint,
      );
    }

    /// transfer firmware image
    try {
      await _transferObject(
        type: NrfDfuTransferType.image.code,
        buffer: bin,
        controlPoint: controlPoint,
        dataPoint: dataPoint,
      );
    } catch (_) {
      await Future.delayed(const Duration(seconds: 1));
      await _transferObject(
        type: NrfDfuTransferType.image.code,
        buffer: bin,
        controlPoint: controlPoint,
        dataPoint: dataPoint,
      );
    }
  }

  Future<void> enterDfuMode(BluetoothDevice device) async {
    final cp = setup.entryControlPoint;
    
    // Retry discoverServices if it fails due to transient disconnection
    List<BluetoothService> services;
    try {
      services = await device.discoverServices();
    } catch (e) {
      log('Discovery failed, retrying connection once...', level: 'WARNING');
      await device.connect(license: License.free, timeout: const Duration(seconds: 3));
      services = await device.discoverServices();
    }

    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.characteristicUuid == Guid.fromString(cp)) {
          entry.controlPoint = c;
          break;
        }
      }
    }
    
    if (entry.controlPoint == null) throw Exception('Entry control point not found');
    await entry.controlPoint!.write(setup.entryPacket);
  }

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isAutoDfuRunning = false;

  Future<void> autoDfu() async {
    if (file.datPath == null) throw Exception('dat file not found');
    if (file.binPath == null) throw Exception('bin file not found');
    if (_isAutoDfuRunning) return;

    if (!FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        continuousUpdates: true,
      );
    }
  }

  Future<void> _processAutoDfu(List<ScanResult> results) async {
    if (_isAutoDfuRunning) return;
    if (!setup.isAutoUpdateEnabled) return;

    final targets = results
        .where((s) => RegExp(autoEntryDeviceName).hasMatch(s.device.platformName))
        .where((s) => !setup.updatedMacs.contains(s.device.remoteId.str))
        .where((s) => !setup.autoDfuFinished.any((d) => d.remoteId == s.device.remoteId))
        .where((s) {
          final cooldown = _failedCooldown[s.device.remoteId.str];
          return cooldown == null || DateTime.now().isAfter(cooldown);
        })
        .map((s) => s.device)
        .toList();

    if (targets.isEmpty) return;

    _isAutoDfuRunning = true;
    final entry = targets.first;
    final remoteId = entry.remoteId.str;
    final deviceName = entry.platformName;

    try {
      log('Target found: $deviceName ($remoteId). Connecting...');
      // Removed stopScan and delay to speed up connection on Windows
      await entry.connect(license: License.free, timeout: const Duration(seconds: 3));
      
      // Request MTU to stabilize connection
      try {
        await entry.requestMtu(247);
      } catch (_) {}

      log('Entering DFU mode...');
      await enterDfuMode(entry);

      // Wait for device to reappear in DFU mode
      log('Waiting for $autoDfuDeviceName...');
      BluetoothDevice? dfuDevice;
      final timeout = DateTime.now().add(const Duration(seconds: 15));
      
      // Start scan again to find DFU device
      await FlutterBluePlus.startScan(continuousUpdates: true);
      
      while (DateTime.now().isBefore(timeout)) {
        final currentResults = await FlutterBluePlus.scanResults.first;
        dfuDevice = currentResults
            .where((s) => RegExp(autoDfuDeviceName).hasMatch(s.device.platformName))
            .where((s) => s.device.remoteId == entry.remoteId || s.device.platformName == autoDfuDeviceName)
            .singleOrNull
            ?.device;
        if (dfuDevice != null) break;
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (dfuDevice == null) {
        throw Exception('DFU device not found after entry');
      }

      log('DFU device found. Connecting for firmware update...');
      await dfuDevice.connect(license: License.free, timeout: const Duration(seconds: 3));
      try {
        await dfuDevice.requestMtu(247);
      } catch (_) {}
      
      await updateFirmware(dfuDevice);

      addHistoryEntry(
        remoteId: remoteId,
        deviceName: deviceName,
        status: 'success',
      );
      setup.autoDfuFinished.add(entry);
    } catch (e) {
      log('Auto DFU error: $e', level: 'ERROR');
      _failedCooldown[remoteId] = DateTime.now().add(const Duration(seconds: 5));
      addHistoryEntry(
        remoteId: remoteId,
        deviceName: deviceName,
        status: 'failed',
        note: e.toString(),
      );
    } finally {
      _isAutoDfuRunning = false;
      // Resume scan if still enabled
      if (setup.isAutoScanEnabled || setup.isAutoUpdateEnabled) {
        _startAutoScan();
      }
    }
  }

  Timer? _autoScanTimer;

  void toggleAutoScan(bool enable) {
    runInAction(() {
      setup.isAutoScanEnabled = enable;
      _checkAutoScanLoop();
    });
  }

  void toggleAutoUpdate(bool enable) {
    runInAction(() {
      setup.isAutoUpdateEnabled = enable;
      _checkAutoScanLoop();
    });
  }

  void _checkAutoScanLoop() {
    final shouldRun = setup.isAutoScanEnabled || setup.isAutoUpdateEnabled;
    if (shouldRun) {
      _startAutoScan();
    } else {
      _stopAutoScan();
    }
  }

  void _stopAutoScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
  }

  void _startAutoScan() {
    _stopAutoScan();
    if (!setup.isAutoScanEnabled && !setup.isAutoUpdateEnabled) return;

    // Start aggressive scan
    FlutterBluePlus.startScan(continuousUpdates: true);

    // Reactive processing: act immediately when results change
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      runInAction(() {
        // Update UI target list
        final filtered = results
            .where((s) => RegExp(autoEntryDeviceName).hasMatch(s.device.platformName))
            .where((s) => !setup.updatedMacs.contains(s.device.remoteId.str))
            .where((s) => !setup.autoDfuFinished.any((d) => d.remoteId == s.device.remoteId))
            .where((s) {
              final cooldown = _failedCooldown[s.device.remoteId.str];
              return cooldown == null || DateTime.now().isAfter(cooldown);
            })
            .map((s) => s.device)
            .toList();
        
        setup.autoDfuTargets.clear();
        setup.autoDfuTargets.addAll(filtered);
      });

      // Trigger DFU processing
      _processAutoDfu(results);
    });

    // Fallback timer to ensure scan stays alive or triggers periodically if stream is quiet
    _autoScanTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!FlutterBluePlus.isScanningNow) {
        FlutterBluePlus.startScan(continuousUpdates: true);
      }
    });
  }

  Future<void> refresh() async {
    setup.autoDfuTargets.clear();
    setup.autoDfuFinished.clear();
    await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan();
  }
}

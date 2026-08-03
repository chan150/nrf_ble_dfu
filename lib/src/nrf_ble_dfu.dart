import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path/path.dart';

import 'state/state.dart';
import 'enum/enum.dart';
import 'extension/extension.dart';

export 'dart:async';
export 'dart:io';

class NrfBleDfu {
  factory NrfBleDfu() => _instance;

  static final _instance = NrfBleDfu._internal();

  NrfBleDfu._internal();

  bool _isInitialized = false;

  // Stream controllers to emit events to external subscribers (e.g. UI/Storage packages)
  final _logStreamController = StreamController<LogEntry>.broadcast();
  Stream<LogEntry> get onLog => _logStreamController.stream;

  final _historyStreamController =
      StreamController<DfuHistoryEntry>.broadcast();
  Stream<DfuHistoryEntry> get onHistory => _historyStreamController.stream;

  final _historyDeleteStreamController =
      StreamController<DfuHistoryEntry>.broadcast();
  Stream<DfuHistoryEntry> get onHistoryDelete =>
      _historyDeleteStreamController.stream;

  final _historyClearStreamController = StreamController<void>.broadcast();
  Stream<void> get onHistoryClear => _historyClearStreamController.stream;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    _done();
  }

  final entry = BleDeviceState();
  final dfu = BleDeviceState();
  final file = DfuFileState();
  final setup = DfuSetupState();
  final progress = DfuProgressState();

  final List<DfuPreset> presets = [];
  int? selectedPresetIndex;

  final Map<String, DateTime> _failedCooldown = {};

  String _extractSerialNumber(String name) {
    if (name.contains('_')) {
      return name.split('_').last;
    }
    return name;
  }

  bool _isDuplicate(String name, String remoteId) {
    final fwName = file.path != null ? basename(file.path!) : '';
    final serial = _extractSerialNumber(name);
    return setup.history.any((h) =>
        h.status == 'success' &&
        h.firmwareName == fwName &&
        h.remoteId == remoteId &&
        h.serialNumber == serial);
  }

  void addHistoryEntry({
    required String remoteId,
    required String deviceName,
    required String status,
    String? note,
  }) {
    final fwName = file.path != null ? basename(file.path!) : '';
    final serial = _extractSerialNumber(deviceName);
    final historyEntry = DfuHistoryEntry(
      remoteId: remoteId,
      deviceName: deviceName,
      timestamp: DateTime.now(),
      status: status,
      note: note,
      firmwareName: fwName,
      serialNumber: serial,
    );
    setup.history.insert(0, historyEntry);
    if (status == 'success') {
      setup.updatedMacs.add(remoteId);
    }
    setup.notify();
    _historyStreamController.add(historyEntry);
  }

  void deleteHistoryEntry(DfuHistoryEntry entry) {
    setup.history.removeWhere(
        (h) => h.remoteId == entry.remoteId && h.timestamp == entry.timestamp);
    setup.updatedMacs.remove(entry.remoteId);
    setup.notify();
    _historyDeleteStreamController.add(entry);
  }

  void log(String message, {String level = 'INFO'}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
    );
    setup.logs.add(entry);
    if (setup.logs.length > setup.maxLogs) {
      setup.logs.removeAt(0);
    }
    setup.notify();
    _logStreamController.add(entry);
  }

  void retryDfu(String remoteId) {
    setup.updatedMacs.remove(remoteId);
    setup.autoDfuFinished.removeWhere((d) => d.remoteId.str == remoteId);
    setup.notify();
  }

  Future<void> clearHistory() async {
    setup.history.clear();
    setup.updatedMacs.clear();
    setup.autoDfuFinished.clear();
    setup.notify();
    _historyClearStreamController.add(null);
    log('All history cleared.');
  }

  final _completed = Completer<void>();

  void _done() {
    if (!_completed.isCompleted) {
      _completed.complete();
    }
  }

  Future<void> waitForCompletion() async {
    await _completed.future;
    log('Completed $runtimeType');
  }

  String get entryControlPoint => setup.entryControlPoint;

  set entryControlPoint(String value) {
    setup.entryControlPoint = value;
    selectedPresetIndex = null;
    setup.notify();
  }

  List<int> get entryPacket => setup.entryPacket;

  set entryPacket(List<int> value) {
    setup.entryPacket.clear();
    setup.entryPacket.addAll(value);
    selectedPresetIndex = null;
    setup.notify();
  }

  String get autoEntryDeviceName => setup.autoEntryDeviceName;

  set autoEntryDeviceName(String value) {
    setup.autoEntryDeviceName = value;
    selectedPresetIndex = null;
    setup.notify();
  }

  String get autoDfuDeviceName => setup.autoDfuDeviceName;

  set autoDfuDeviceName(String value) {
    setup.autoDfuDeviceName = value;
    selectedPresetIndex = null;
    setup.notify();
  }

  void loadPreset(int index) {
    if (index < 0 || index >= presets.length) return;
    final p = presets[index];
    setup.entryControlPoint = p.entryUuid;
    setup.entryPacket.clear();
    setup.entryPacket.addAll(p.entryPkt.fromRawHex);
    setup.autoEntryDeviceName = p.targetName;
    setup.autoDfuDeviceName = p.targetDfuName;
    selectedPresetIndex = index;
    setup.notify();
  }

  void updatePreset(int index) {
    if (index < 0 || index >= presets.length) return;
    presets[index] = DfuPreset(
      name: presets[index].name,
      entryUuid: entryControlPoint,
      entryPkt: entryPacket.rawHex,
      targetName: autoEntryDeviceName,
      targetDfuName: autoDfuDeviceName,
    );
    setup.notify();
  }

  void renamePreset(int index, String name) {
    if (index < 0 || index >= presets.length) return;
    final p = presets[index];
    presets[index] = DfuPreset(
      name: name,
      entryUuid: p.entryUuid,
      entryPkt: p.entryPkt,
      targetName: p.targetName,
      targetDfuName: p.targetDfuName,
    );
    setup.notify();
  }

  void addNewPreset(String name) {
    presets.add(DfuPreset(
      name: name,
      entryUuid: entryControlPoint,
      entryPkt: entryPacket.rawHex,
      targetName: autoEntryDeviceName,
      targetDfuName: autoDfuDeviceName,
    ));
    selectedPresetIndex = presets.length - 1;
    setup.notify();
  }

  void deletePreset(int index) {
    if (index < 0 || index >= presets.length) return;
    if (presets.length <= 1) return;
    presets.removeAt(index);
    selectedPresetIndex = null;
    setup.notify();
  }

  Future<void> setFirmwareFile(
      String path, List<int> bytes, String tempDir) async {
    file.path = path;
    await extractZip(bytes, tempDir);
  }

  Future<void> extractZip(List<int> bytes, String tempDir) async {
    final outputPath = join(tempDir, "firmware_files");
    final outputDir = Directory(outputPath);
    await outputDir.create(recursive: true);
    if (!outputDir.existsSync()) return;
    file.outputPath = outputPath;

    await extractArchiveToDisk(ZipDecoder().decodeBytes(bytes), outputPath);

    final list = outputDir.listSync();
    final datFile =
        list.where((e) => e.path.endsWith('dat')).singleOrNull?.path;
    final binFile =
        list.where((e) => e.path.endsWith('bin')).singleOrNull?.path;
    file.update(datPath: datFile, binPath: binFile);
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

    late int from;
    late int to;
    late List<int> data;

    bool isPrepared = false;
    bool isSelectCommand = true;
    int step = 0;

    progress.reset();

    await for (final event in controlPoint.lastValueStream) {
      if (event.elementAtOrNull(0) == NrfDfuOp.response.code) {
        log(event.hexString);
      }

      if (isSelectCommand) {
        isSelectCommand = false;
        await controlPoint.write([NrfDfuOp.objectSelect.code, type]);
        continue;
      }

      if (event.elementAtOrNull(0) != NrfDfuOp.response.code) {
        log('Not response packet: $event');
        continue;
      }

      if (event.elementAtOrNull(0) == NrfDfuOp.response.code &&
          event.elementAtOrNull(1) == NrfDfuOp.objectSelect.code &&
          event.elementAtOrNull(2) == NrfDfuResult.success.code) {
        maxSize = event.getInt32(3);
        offset = event.getInt32(7);
        crc = event.getInt32(11);

        from = step * maxSize;
        to = math.min((step + 1) * maxSize, buffer.length);
        data = buffer.sublist(from, to);

        progress.update(
          fileSize: buffer.length,
          completedSize: 0,
        );

        final sizePacket = data.length.toBytes;
        await controlPoint
            .write([NrfDfuOp.objectCreate.code, type, ...sizePacket]);
        continue;
      }

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

      if (event.elementAtOrNull(0) == NrfDfuOp.response.code &&
          event.elementAtOrNull(1) == NrfDfuOp.crcGet.code &&
          event.elementAtOrNull(2) == NrfDfuResult.success.code) {
        offset = event.getInt32(3);
        crc = event.getInt32(7);

        log((_crc32(buffer.sublist(0, offset)), offset, crc).toString());

        if (isPrepared) {
          await controlPoint.write([NrfDfuOp.objectExecute.code]);
        }
        isPrepared = false;
        continue;
      }

      if (event.elementAtOrNull(0) == NrfDfuOp.response.code &&
          event.elementAtOrNull(1) == NrfDfuOp.objectExecute.code &&
          event.elementAtOrNull(2) == NrfDfuResult.success.code) {
        final current = progress.completedSize ?? 0;
        progress.update(completedSize: current + data.length);

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
        if (c.uuid.toString().toLowerCase() ==
            setup.dfuControlPoint.toLowerCase()) {
          dfu.update(controlPoint: c);
        }
        if (c.uuid.toString().toLowerCase() ==
            setup.dfuDataPoint.toLowerCase()) {
          dfu.update(dataPoint: c);
        }
      }
    }

    final controlPoint = dfu.controlPoint;
    final dataPoint = dfu.dataPoint;

    if (controlPoint == null) throw Exception('Control point not found');
    if (dataPoint == null) throw Exception('Data point not found');

    await controlPoint.setNotifyValue(true);

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

    List<BluetoothService> services;
    try {
      services = await device.discoverServices();
    } catch (e) {
      log('Discovery failed, retrying connection once...', level: 'WARNING');
      await device.connect(
          license: License.nonprofit, timeout: const Duration(seconds: 3));
      services = await device.discoverServices();
    }

    entry.update(controlPoint: null);
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.uuid.toString().toLowerCase() == cp.toLowerCase()) {
          entry.update(controlPoint: c);
          break;
        }
      }
    }

    if (entry.controlPoint == null) {
      throw Exception('Entry control point not found');
    }

    try {
      await entry.controlPoint!.write(setup.entryPacket);
    } catch (e) {
      log('DFU entry write: $e (device may be rebooting)', level: 'WARNING');
    }
  }

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isAutoDfuRunning = false;
  Timer? _autoScanTimer;

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

    final candidates = results.where((s) {
      final name = s.device.platformName;
      final isApp = RegExp(autoEntryDeviceName).hasMatch(name);
      final isDfu = RegExp(autoDfuDeviceName).hasMatch(name);
      return (isApp || isDfu) &&
          !_isDuplicate(s.device.platformName, s.device.remoteId.str) &&
          !setup.autoDfuFinished
              .any((d) => d.remoteId.str == s.device.remoteId.str);
    }).where((s) {
      final cooldown = _failedCooldown[s.device.remoteId.str];
      return cooldown == null || DateTime.now().isAfter(cooldown);
    }).toList();

    if (candidates.isEmpty) return;

    final selectedScan = candidates.firstWhere(
        (s) => RegExp(autoDfuDeviceName).hasMatch(s.device.platformName),
        orElse: () => candidates.first);

    _isAutoDfuRunning = true;
    final device = selectedScan.device;
    final remoteId = device.remoteId.str;
    final deviceName = device.platformName;
    final isAlreadyInDfu = RegExp(autoDfuDeviceName).hasMatch(deviceName);

    try {
      if (!isAlreadyInDfu) {
        log('Target found: $deviceName ($remoteId). Connecting...');
        await device.connect(
            license: License.nonprofit, timeout: const Duration(seconds: 3));

        try {
          await device.requestMtu(247);
        } catch (_) {}

        log('Entering DFU mode...');
        await enterDfuMode(device);

        log('Waiting for $autoDfuDeviceName...');
        BluetoothDevice? dfuDevice;
        final timeout = DateTime.now().add(const Duration(seconds: 15));

        await FlutterBluePlus.startScan(continuousUpdates: true);

        while (DateTime.now().isBefore(timeout)) {
          final currentResults = await FlutterBluePlus.scanResults.first;
          dfuDevice = currentResults
              .where((s) =>
                  RegExp(autoDfuDeviceName).hasMatch(s.device.platformName))
              .where((s) =>
                  s.device.remoteId.str == device.remoteId.str ||
                  s.device.platformName == autoDfuDeviceName)
              .firstOrNull
              ?.device;
          if (dfuDevice != null) break;
          await Future.delayed(const Duration(milliseconds: 200));
        }

        if (dfuDevice == null) {
          throw Exception('DFU device not found after entry');
        }

        log('DFU device found. Connecting for firmware update...');
        await dfuDevice.connect(
            license: License.nonprofit, timeout: const Duration(seconds: 3));
        try {
          await dfuDevice.requestMtu(247);
        } catch (_) {}

        await updateFirmware(dfuDevice);
      } else {
        log('Target already in DFU mode: $deviceName ($remoteId). Connecting for update...');
        await device.connect(
            license: License.nonprofit, timeout: const Duration(seconds: 3));
        try {
          await device.requestMtu(247);
        } catch (_) {}

        await updateFirmware(device);
      }

      addHistoryEntry(
        remoteId: remoteId,
        deviceName: deviceName,
        status: 'success',
      );
      setup.autoDfuFinished.add(device);
      setup.notify();
    } catch (e) {
      log('Auto DFU error: $e', level: 'ERROR');
      _failedCooldown[remoteId] =
          DateTime.now().add(const Duration(seconds: 5));
      addHistoryEntry(
        remoteId: remoteId,
        deviceName: deviceName,
        status: 'failed',
        note: e.toString(),
      );
    } finally {
      _isAutoDfuRunning = false;
      if (setup.isAutoScanEnabled || setup.isAutoUpdateEnabled) {
        _startAutoScan();
      }
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

    FlutterBluePlus.startScan(continuousUpdates: true);

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      final filtered = results
          .where((s) {
            final name = s.device.platformName;
            final isApp = RegExp(autoEntryDeviceName).hasMatch(name);
            final isDfu = RegExp(autoDfuDeviceName).hasMatch(name);
            return (isApp || isDfu);
          })
          .where((s) =>
              !_isDuplicate(s.device.platformName, s.device.remoteId.str))
          .where((s) => !setup.autoDfuFinished
              .any((d) => d.remoteId.str == s.device.remoteId.str))
          .where((s) {
            final cooldown = _failedCooldown[s.device.remoteId.str];
            return cooldown == null || DateTime.now().isAfter(cooldown);
          })
          .map((s) => s.device)
          .toList();

      setup.autoDfuTargets.clear();
      setup.autoDfuTargets.addAll(filtered);
      setup.notify();

      if (setup.isAutoUpdateEnabled) {
        _processAutoDfu(results);
      }
    });

    _autoScanTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!FlutterBluePlus.isScanningNow) {
        FlutterBluePlus.startScan(continuousUpdates: true);
      }
    });
  }

  void toggleAutoScan(bool enable) {
    setup.isAutoScanEnabled = enable;
    setup.notify();
    _checkAutoScanLoop();
  }

  void toggleAutoUpdate(bool enable) {
    setup.isAutoUpdateEnabled = enable;
    setup.notify();
    _checkAutoScanLoop();
  }

  void _checkAutoScanLoop() {
    final shouldRun = setup.isAutoScanEnabled || setup.isAutoUpdateEnabled;
    if (shouldRun) {
      _startAutoScan();
    } else {
      _stopAutoScan();
    }
  }

  Future<void> refresh() async {
    setup.autoDfuTargets.clear();
    setup.autoDfuFinished.clear();
    setup.notify();
    await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan();
  }
}

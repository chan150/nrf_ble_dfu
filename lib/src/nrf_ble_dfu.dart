import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mobx/mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'dart:async';
export 'dart:io';

class NrfBleDfu {
  factory NrfBleDfu() => _instance;

  static final _instance = NrfBleDfu._internal();

  NrfBleDfu._internal() {
    initializeSharedPreference();
    FlutterBluePlus.setLogLevel(LogLevel.error);
  }

  late SharedPreferences prefs;
  final entry = BleDeviceState();
  final dfu = BleDeviceState();
  final file = DfuFileState();
  final setup = DfuSetupState();
  final progress = DfuProgressState();
  final presets = ObservableList<DfuPreset>();
  final selectedPresetIndex = Observable<int?>(null);

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

    await _done();
  }

  Future<void> waitForCompletion() async {
    await asyncWhen((_) => _completed.value == true);
    log('Completed $runtimeType');
  }

  late final _done = Action(() => _completed.value = true);
  final _completed = Observable(false);

  //////////////////////////////////////////

  String get entryControlPoint => setup.entryControlPoint;

  List<int> get entryPacket => setup.entryPacket;

  String get autoEntryDeviceName => setup.autoEntryDeviceName;

  String get autoDfuDeviceName => setup.autoDfuDeviceName;


  set entryControlPoint(String value) {
    runInAction(() {
      setup.entryControlPoint = value;
      selectedPresetIndex.value = null; // Manual change clears selection
      savePresets();
    });
  }

  set entryPacket(List<int> value) {
    runInAction(() {
      setup.entryPacket.clear();
      setup.entryPacket.addAll(value);
      selectedPresetIndex.value = null;
      savePresets();
    });
  }

  set autoEntryDeviceName(String value) {
    runInAction(() {
      setup.autoEntryDeviceName = value;
      selectedPresetIndex.value = null;
      savePresets();
    });
  }

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
    final result = await FilePicker.platform.pickFiles();
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
        progress.completedSize = progress.completedSize! + data.length;

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
    if (file.datPath == null) throw Exception('dat file not found');
    if (file.binPath == null) throw Exception('bin file not found');

    final dat = File(file.datPath!).readAsBytesSync();
    final bin = File(file.binPath!).readAsBytesSync();

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
    final services = await device.discoverServices();

    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.characteristicUuid == Guid.fromString(cp)) {
          entry.controlPoint = c;
          break;
        }
      }
    }
    entry.controlPoint?.write(setup.entryPacket);
  }

  Future<void> autoDfu() async {
    if (file.datPath == null) throw Exception('dat file not found');
    if (file.binPath == null) throw Exception('bin file not found');
    if (!FlutterBluePlus.isScanningNow) await FlutterBluePlus.startScan();
    if (!setup.enableTargetEntryProcess) setup.autoDfuTargets.clear();
    final scanResults = await FlutterBluePlus.scanResults.first;
    setup.autoDfuTargets.addAll([
      ...scanResults
          .where((s) =>
              RegExp(autoEntryDeviceName).hasMatch(s.device.platformName))
          .map((e) => e.device)
    ]);
    setup.autoDfuTargets.removeAll(setup.autoDfuFinished);

    late BluetoothDevice entry;
    while (setup.autoDfuTargets.isNotEmpty) {
      entry = setup.autoDfuTargets.first;
      try {
        await entry.connect(license: License.free);
        await enterDfuMode(entry);
        await for (final scanResult in FlutterBluePlus.scanResults) {
          final dfu = scanResult
              .where((s) =>
                  RegExp(autoDfuDeviceName).hasMatch(s.device.platformName))
              .singleOrNull
              ?.device;
          if (dfu == null) continue;

          await dfu.connect(license: License.free);
          await updateFirmware(dfu);
          break;
        }
      } catch (e) {
        log(e.toString());
        break;
      }

      setup.autoDfuTargets.remove(entry);
      setup.autoDfuFinished.add(entry);
    }
  }

  Future<void> refresh() async {
    setup.autoDfuTargets.clear();
    setup.autoDfuFinished.clear();
    await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan();
  }
}

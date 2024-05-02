import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
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

  Future<void> initializeSharedPreference() async {
    prefs = await SharedPreferences.getInstance();
    setup.autoEntryDeviceName = prefs.getString('autoEntryDeviceName') ?? '';
    setup.autoDfuDeviceName = prefs.getString('autoDfuDeviceName') ?? '';
    await _done();
  }

  Future<void> waitForCompletion() async {
    await asyncWhen((_) => _completed.value == true);
    log('Completed $runtimeType');
  }

  late final _done = Action(() => _completed.value = true);
  final _completed = Observable(false);

  String get autoEntryDeviceName => setup.autoEntryDeviceName;
  String get autoDfuDeviceName => setup.autoDfuDeviceName;

  set autoEntryDeviceName(String value){
    setup.autoEntryDeviceName = value;
    prefs.setString('autoEntryDeviceName', value);
  }

  set autoDfuDeviceName(String value){
    setup.autoDfuDeviceName = value;
    prefs.setString('autoDfuDeviceName', value);
  }

  Future<void> selectDfu() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    file.path = result.paths.single;

    final tempDir = await getTemporaryDirectory();
    final outputPath = join(tempDir.path, "firmware_files");
    final outputDir = Directory(outputPath);
    await outputDir.create();
    if (!outputDir.existsSync()) return;
    file.outputPath = outputPath;

    await extractFileToDisk(file.path!, outputPath);
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

    NrfBleDfu().progress.fileSize = null;
    NrfBleDfu().progress.completedSize = null;

    /// https://infocenter.nordicsemi.com/index.jsp?topic=%2Fsdk_nrf5_v17.0.2%2Flib_bootloader_dfu_process.html
    await for (final event in controlPoint.lastValueStream) {
      log(event.hexString);

      /// select command
      /// [06 01]
      if (isSelectCommand) {
        isSelectCommand = false;
        controlPoint.write([
          NrfDfuOp.objectSelect.code,
          type,
        ]);
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
        NrfBleDfu().progress.fileSize ??= buffer.length;
        NrfBleDfu().progress.completedSize ??= 0;

        // final checkSize = offset == dat.length;
        // final checkCrc = crc == crc32(dat);
        // if(checkInit && checkSize && checkCrc){
        //   log('Init packet already received');
        // }

        final sizePacket = data.length.toBytes;
        await controlPoint.write([
          NrfDfuOp.objectCreate.code,
          type,
          ...sizePacket,
        ]);
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
          final packet = data.sublist(i * 20, math.min((i + 1) * 20, data.length));
          await dataPoint.write(packet, withoutResponse: true);
        }
        controlPoint.write([NrfDfuOp.crcGet.code]);
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

        if (isPrepared) controlPoint.write([NrfDfuOp.objectExecute.code]);
        isPrepared = false;
        continue;
      }

      /// Response Execute Success
      /// [60 04 01]
      if (event.elementAtOrNull(0) == NrfDfuOp.response.code &&
          event.elementAtOrNull(1) == NrfDfuOp.objectExecute.code &&
          event.elementAtOrNull(2) == NrfDfuResult.success.code) {
        NrfBleDfu().progress.completedSize = NrfBleDfu().progress.completedSize! + data.length;

        if (step + 1 < buffer.length / maxSize) {
          controlPoint.write([
            NrfDfuOp.objectSelect.code,
            type,
          ]);
          step++;
          continue;
        } else {
          break;
        }
      }

      log('Unhandled packet: $event');
      break;
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

    final cp = setup.dfuControlPoint;
    final dp = setup.dfuDataPoint;
    final services = await device.discoverServices();

    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.characteristicUuid == Guid.fromString(cp)) {
          dfu.controlPoint = c;
        }
        if (c.characteristicUuid == Guid.fromString(dp)) {
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
    await _transferObject(
      type: NrfDfuTransferType.init.code,
      buffer: dat,
      controlPoint: controlPoint,
      dataPoint: dataPoint,
    );

    /// transfer firmware image
    await _transferObject(
      type: NrfDfuTransferType.image.code,
      buffer: bin,
      controlPoint: controlPoint,
      dataPoint: dataPoint,
    );
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
}

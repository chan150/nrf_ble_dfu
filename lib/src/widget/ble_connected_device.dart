import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class BleConnectedDevice extends StatelessWidget {
  const BleConnectedDevice({super.key});

  Future<void> _enterDfuMode(BluetoothDevice device) async {
    final cp = NrfBleDfu().setup.entryControlPoint;
    final services = await device.discoverServices();

    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.characteristicUuid == Guid.fromString(cp)) {
          NrfBleDfu().entry.controlPoint = c;
          break;
        }
      }
    }
    NrfBleDfu().entry.controlPoint?.write(NrfBleDfu().setup.entryPacket);
  }

  Future<void> _updateFirmware(BluetoothDevice device) async {
    if (NrfBleDfu().file.datPath == null) throw Exception('dat file not found');
    if (NrfBleDfu().file.binPath == null) throw Exception('bin file not found');

    final dat = File(NrfBleDfu().file.datPath!).readAsBytesSync();
    final bin = File(NrfBleDfu().file.binPath!).readAsBytesSync();

    final cp = NrfBleDfu().setup.dfuControlPoint;
    final dp = NrfBleDfu().setup.dfuDataPoint;
    final services = await device.discoverServices();

    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.characteristicUuid == Guid.fromString(cp)) {
          NrfBleDfu().dfu.controlPoint = c;
        }
        if (c.characteristicUuid == Guid.fromString(dp)) {
          NrfBleDfu().dfu.dataPoint = c;
        }
      }
    }

    final controlPoint = NrfBleDfu().dfu.controlPoint;
    final dataPoint = NrfBleDfu().dfu.dataPoint;

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

  Future<void> _transferObject({
    required int type,
    required Uint8List buffer,
    required BluetoothCharacteristic controlPoint,
    required BluetoothCharacteristic dataPoint,
  }) async {
    late int maxSize;
    late int offset;
    late int crc;
    int step = 0;

    ///
    late int from;
    late int to;
    late List<int> data;

    bool isSelectCommand = true;

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
        log('========================= $step');
        from = step * maxSize;
        to = math.min((step + 1) * maxSize, buffer.length);
        data = buffer.sublist(from, to);
        for (var i = 0; i < data.length / 20; i++) {
          final packet = data.sublist(i * 20, math.min((i + 1) * 20, data.length));
          await dataPoint.write(packet, withoutResponse: true);
        }
        await controlPoint.write([NrfDfuOp.crcGet.code]);
        step++;
        continue;
      }

      /// Response PRN Success: offset CRC32
      /// [60 03 01 XXXXXXXX XXXXXXXX]
      if (event.elementAtOrNull(0) == NrfDfuOp.response.code &&
          event.elementAtOrNull(1) == NrfDfuOp.crcGet.code &&
          event.elementAtOrNull(2) == NrfDfuResult.success.code) {
        offset = event.getInt32(3);
        crc = event.getInt32(7);
        log((crc32(buffer.sublist(0, offset)), offset, crc).toString());

        /// Execute command
        /// [04]
        if (step + 1 < buffer.length / maxSize) {
          log('========================= $step');
          from = step * maxSize;
          to = math.min((step + 1) * maxSize, buffer.length);
          data = buffer.sublist(from, to);
          for (var i = 0; i < data.length / 20; i++) {
            final packet = data.sublist(i * 20, math.min((i + 1) * 20, data.length));
            await dataPoint.write(packet, withoutResponse: true);
          }
          await controlPoint.write([NrfDfuOp.crcGet.code]);
          step++;
        } else {
          controlPoint.write([NrfDfuOp.objectExecute.code]);
        }
        continue;
      }

      if (event.elementAtOrNull(0) == NrfDfuOp.response.code &&
          event.elementAtOrNull(1) == NrfDfuOp.objectExecute.code &&
          event.elementAtOrNull(2) == NrfDfuResult.success.code) {
        break;
      }

      log('Unhandled packet');
      break;
    }
  }

  int crc32(List<int> buffer) {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(
        const Duration(milliseconds: 100),
        (i) => FlutterBluePlus.connectedDevices,
      ).distinct(),
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        return ListView.builder(
          shrinkWrap: true,
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return ListTile(
              title: Text(item.platformName),
              subtitle: Text(item.remoteId.str),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _enterDfuMode(item),
                    tooltip: 'Enter DFU mode',
                    icon: const Icon(Icons.published_with_changes_sharp),
                  ),
                  IconButton(
                    onPressed: () => _updateFirmware(item),
                    tooltip: 'Update firmware',
                    icon: const Icon(Icons.system_update_alt),
                  ),
                  IconButton(
                    onPressed: item.disconnect,
                    tooltip: 'Disconnect device',
                    icon: const Icon(Icons.bluetooth_disabled),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

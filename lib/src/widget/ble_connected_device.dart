import 'dart:developer';

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

    late int maxSize;
    late int offset;
    late int type;
    late int crc;

    /// https://infocenter.nordicsemi.com/index.jsp?topic=%2Fsdk_nrf5_v17.0.2%2Flib_bootloader_dfu_process.html
    await for (final event in controlPoint.lastValueStream) {
      log(event.hexString);
      if (event.isEmpty) {
        /// select command [06 01]
        type = NrfDfuTransferType.init.code;
        controlPoint.write([
          NrfDfuOp.objectSelect.code,
          NrfDfuTransferType.init.code,
        ]);
        continue;
      }

      /// response select success: max_size offset CRC32
      /// [60 06 01 XXXXXXXX XXXXXXXX XXXXXXXX]
      if (event[0] == NrfDfuOp.response.code) {
        maxSize = event.getInt32(3);
        offset = event.getInt32(7);
        crc = event.getInt32(11);

        final isInit = type == NrfDfuTransferType.init.code;
        final isSameSize = offset == dat.length;

        // log((type, maxSize, offset, crc, dat.length).toString());
        // log(crc32(dat).toString());
        // log(crc32(bin).toString());
        break;
      }
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

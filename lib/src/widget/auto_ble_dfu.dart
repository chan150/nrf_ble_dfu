import 'package:flutter/material.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class AutoBleDfu extends StatelessObserverWidget {
  const AutoBleDfu({super.key});

  Future<void> _autoDfu() async {
    if (!FlutterBluePlus.isScanningNow) await FlutterBluePlus.startScan();
    if (!NrfBleDfu().setup.enableTargetEntryProcess) NrfBleDfu().setup.autoDfuTargets.clear();
    final scanResults = await FlutterBluePlus.scanResults.first;
    NrfBleDfu().setup.autoDfuTargets.addAll([
      ...scanResults
          .where((s) => RegExp(NrfBleDfu().autoEntryDeviceName).hasMatch(s.device.platformName))
          .map((e) => e.device)
    ]);
    NrfBleDfu().setup.autoDfuTargets.removeAll(NrfBleDfu().setup.autoDfuFinished);

    late BluetoothDevice entry;
    while (NrfBleDfu().setup.autoDfuTargets.isNotEmpty) {
      entry = NrfBleDfu().setup.autoDfuTargets.first;
      try {
        await entry.connect();
        await NrfBleDfu().enterDfuMode(entry);
        await for (final scanResult in FlutterBluePlus.scanResults) {
          final dfu = scanResult
              .where((s) => RegExp(NrfBleDfu().autoDfuDeviceName).hasMatch(s.device.platformName))
              .singleOrNull
              ?.device;
          if (dfu == null) continue;
          await dfu.connect();
          await NrfBleDfu().updateFirmware(dfu);
          break;
        }
      } catch (e) {
        log(e.toString());
        break;
      }

      NrfBleDfu().setup.autoDfuTargets.remove(entry);
      NrfBleDfu().setup.autoDfuFinished.add(entry);
    }
  }

  Future<void> _refresh()async{
    NrfBleDfu().setup.autoDfuFinished.clear();
  }

  @override
  Widget build(BuildContext context) {
    const div = Divider(height: 0, color: Colors.transparent);
    return Wrap(
      children: [
        IconButton(
          onPressed: _autoDfu,
          tooltip: 'Play auto DFU',
          icon: const Icon(Icons.play_arrow_sharp),
        ),
        IconButton(
          onPressed: _refresh,
          tooltip: 'Refresh finished devices',
          icon: const Icon(Icons.refresh),
        ),
        div,
        const Text('Waiting Queue: '),
        div,
        for (final item in NrfBleDfu().setup.autoDfuTargets.difference(NrfBleDfu().setup.autoDfuFinished))
          Text('${item.platformName}[${item.remoteId}]'),
        div,
        const Text('Finished Devices: '),
        div,
        for (final item in NrfBleDfu().setup.autoDfuFinished) Text('${item.platformName}[${item.remoteId}]'),
      ],
    );
  }
}

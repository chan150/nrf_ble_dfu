import 'package:flutter/material.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class AutoBleDfu extends StatelessObserverWidget {
  const AutoBleDfu({super.key});

  Future<void> _autoDfu() async {
    if (!NrfBleDfu().setup.enableTargetEntryProcess) NrfBleDfu().setup.autoDfuTargets.clear();
    final scanResults = await FlutterBluePlus.scanResults.first;
    NrfBleDfu().setup.autoDfuTargets.addAll([
      ...scanResults
          .where((s) => RegExp(NrfBleDfu().autoEntryDeviceName).hasMatch(s.device.platformName))
          .map((e) => e.device)
    ]);

    late BluetoothDevice entry;
    while(NrfBleDfu().setup.autoDfuTargets.isNotEmpty){
      entry = NrfBleDfu().setup.autoDfuTargets.first;
      print(entry);
      await Future.delayed(const Duration(seconds: 1));


      NrfBleDfu().setup.autoDfuTargets.remove(entry);
      NrfBleDfu().setup.autoDfuFinished.add(entry);
    }


  }

  @override
  Widget build(BuildContext context) {
    const div = Divider(height: 0, color: Colors.transparent);
    return Wrap(
      children: [
        IconButton(
          onPressed: _autoDfu,
          icon: const Icon(Icons.play_arrow_sharp),
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

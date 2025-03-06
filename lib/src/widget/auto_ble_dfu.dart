import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class AutoBleDfu extends StatelessObserverWidget {
  const AutoBleDfu({super.key});

  @override
  Widget build(BuildContext context) {
    const div = Divider(height: 0, color: Colors.transparent);
    final diff = NrfBleDfu()
        .setup
        .autoDfuTargets
        .difference(NrfBleDfu().setup.autoDfuFinished);
    return Wrap(
      children: [
        IconButton(
          onPressed: NrfBleDfu().autoDfuParallel,
          tooltip: 'Play auto DFU',
          icon: const Icon(Icons.play_arrow_sharp),
        ),
        IconButton(
          onPressed: NrfBleDfu().refresh,
          tooltip: 'Refresh finished devices',
          icon: const Icon(Icons.refresh),
        ),
        div,
        const Text('Waiting Queue: '),
        div,
        for (final item in diff) Text('${item.platformName}[${item.remoteId}]'),
        div,
        const Text('Finished Devices: '),
        div,
        for (final item in NrfBleDfu().setup.autoDfuFinished)
          Text('${item.platformName}[${item.remoteId}]'),
      ],
    );
  }
}

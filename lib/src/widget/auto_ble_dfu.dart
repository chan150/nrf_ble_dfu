import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class AutoBleDfu extends StatelessObserverWidget {
  const AutoBleDfu({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        const Divider(),
        for(final item in NrfBleDfu().setup.autoDfuTargets)
          Text('${item.platformName}[${item.remoteId}]'),
      ],
    );
  }
}

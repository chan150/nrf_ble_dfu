import 'package:flutter/material.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class BleConnectedDevice extends StatelessWidget {
  const BleConnectedDevice({super.key});

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
          primary: false,
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
                    onPressed: () => NrfBleDfu().enterDfuMode(item),
                    tooltip: 'Enter DFU mode',
                    icon: const Icon(Icons.published_with_changes_sharp),
                  ),
                  IconButton(
                    onPressed: () => NrfBleDfu().updateFirmware(item),
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

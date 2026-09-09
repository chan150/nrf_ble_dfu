import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';

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
                    onPressed: () => _report(
                        'Enter DFU mode',
                        () => NrfBleDfu().enterDfuMode(FbpDevice(item))),
                    tooltip: 'Enter DFU mode',
                    icon: const Icon(Icons.published_with_changes_sharp),
                  ),
                  IconButton(
                    onPressed: () => _report('Update firmware',
                        () => NrfBleDfu().updateFirmware(FbpDevice(item))),
                    tooltip: 'Update firmware',
                    icon: const Icon(Icons.system_update_alt),
                  ),
                  IconButton(
                    onPressed: () => _report('Disconnect', item.disconnect),
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

/// Runs a DFU action from a button and puts any failure in the log.
///
/// These are handed to onPressed, which discards the future, so a throw ends
/// up as an unhandled exception: on a debug build it reaches the console the
/// operator is not reading, and on a release build nowhere at all. The core
/// reports a dropped packet or a bad CRC by throwing -- exactly the failures
/// worth seeing -- so without this they are silent. The automatic path
/// already catches its own; this is the manual one.
Future<void> _report(String action, Future<void> Function() run) async {
  try {
    await run();
  } catch (e) {
    NrfBleDfu().log('$action failed: $e', level: 'ERROR');
  }
}

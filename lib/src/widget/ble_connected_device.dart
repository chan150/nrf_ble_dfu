import 'package:flutter/material.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
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
              leading: SizedBox(
                width: 250,
                height: 50,
                child: Observer(
                  builder: (context) {
                    return DfuProgress(progress: NrfBleDfu().progressSet[item]);
                  },
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // IconButton(
                  //   onPressed: () async {
                  //     final services = await item.discoverServices();
                  //     final characteristics =
                  //         services.expand((s) => s.characteristics);
                  //
                  //     final cp = characteristics
                  //         .where((e) =>
                  //             e.characteristicUuid.str.toUpperCase() == '2CF0')
                  //         .singleOrNull;
                  //     if (cp == null) return;
                  //     await cp.write([0x4E, 0x45, 0x01, 0xF0]);
                  //
                  //     final cp2 = characteristics
                  //         .where((e) =>
                  //             e.characteristicUuid.str.toUpperCase() == '2CF1')
                  //         .singleOrNull;
                  //     if (cp2 == null) return;
                  //     print(await cp2.read());
                  //
                  //     try {
                  //       cp2.setNotifyValue(true);
                  //     } catch (e) {
                  //       print(e);
                  //     }
                  //
                  //     /// qc start
                  //     await cp.write([0x4E, 0x45, 0x01, 0xA0]);
                  //
                  //     Stream.periodic(const Duration(seconds: 5), (i) => i)
                  //         .listen((e) async {
                  //       final now =
                  //           DateTime.now().millisecondsSinceEpoch ~/ 1000;
                  //       final timeStamp = [
                  //         now >> 24,
                  //         (now >> 16 & 0xFF),
                  //         (now >> 8 & 0xFF),
                  //         (now & 0xFF),
                  //       ];
                  //       await cp.write([0x4E, 0x45, 0x05, 0x81, ...timeStamp]);
                  //     });
                  //     cp2.onValueReceived
                  //         .listen((e) => print((DateTime.now(), e)));
                  //   },
                  //   tooltip: 'Custom button',
                  //   icon: const Icon(Icons.dashboard_customize_outlined),
                  // ),
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

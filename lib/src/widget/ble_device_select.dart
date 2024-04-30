import 'package:flutter/material.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

class BleDeviceSelect extends StatefulWidget {
  const BleDeviceSelect({super.key});

  @override
  State<BleDeviceSelect> createState() => _BleDeviceSelectState();
}

class _BleDeviceSelectState extends State<BleDeviceSelect> {
  @override
  void initState() {
    super.initState();
    FlutterBluePlus.startScan();
  }

  @override
  void dispose() {
    super.dispose();
    FlutterBluePlus.stopScan();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FlutterBluePlus.scanResults,
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];

        return ListView.builder(
          shrinkWrap: true,
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return ListTile(
              leading: Text(item.rssi.toString()),
              title: Text(item.device.platformName),
              subtitle: Text(item.device.remoteId.str),
              trailing: IconButton(
                onPressed: item.device.connect,
                icon: const Icon(Icons.bluetooth),
              ),
            );
          },
        );
      },
    );
  }
}

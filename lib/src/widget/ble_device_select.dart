import 'package:flutter/material.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

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
          primary: false,
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return ListTile(
              leading: Text(item.rssi.toString()),
              title: Text(item.device.platformName),
              subtitle: Text(item.device.remoteId.str),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TargetChecker(item: item),
                  CompleteChecker(item: item),
                  IconButton(
                    onPressed: item.device.connect,
                    tooltip: 'Connect device',
                    icon: const Icon(Icons.bluetooth),
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

class TargetChecker extends StatelessObserverWidget {
  const TargetChecker({super.key, required this.item});

  final ScanResult item;

  @override
  Widget build(BuildContext context) {
    final targets = NrfBleDfu().setup.autoDfuTargets;
    final id = item.device.remoteId.str;
    if (!targets.map((e)=>e.remoteId.str).contains(id)) {
      return IconButton(
        onPressed: () => targets.add(item.device),
        tooltip: 'Add device as target',
        icon: const Icon(Icons.circle_outlined),
      );
    }
    return IconButton(
      onPressed: () => targets.remove(item.device),
      tooltip: 'Remove device in targets',
      icon: const Icon(Icons.task_alt_rounded),
    );
  }
}

class CompleteChecker extends StatelessObserverWidget {
  const CompleteChecker({super.key, required this.item});

  final ScanResult item;

  @override
  Widget build(BuildContext context) {
    final completed = NrfBleDfu().setup.autoDfuFinished;
    final id = item.device.remoteId.str;
    if (!completed.map((e)=>e.remoteId.str).contains(id)) {
      return IconButton(
        onPressed: () => completed.add(item.device),
        tooltip: 'Mark device as completed',
        icon: const Icon(Icons.playlist_add),
      );
    }
    return IconButton(
      onPressed: () => completed.remove(item.device),
      tooltip: 'Remove device in complected',
      icon: const Icon(Icons.playlist_add_check),
    );
  }
}

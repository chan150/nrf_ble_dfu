import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

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
                    onPressed: item.disconnect,
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

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

class BleDeviceSelect extends StatelessWidget {
  const BleDeviceSelect({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: stream builder ~ list ~ auto scan 가능한지 테스트
    return StreamBuilder(
      stream: FlutterBluePlus.scanResults.expand((e) => e),
      builder: (context, snapshot) {
        return Text(snapshot.data.toString());
      },
    );

    return ListView(
      shrinkWrap: true,
      children: [
        Text('Ble Device List'),
      ],
    );
  }
}

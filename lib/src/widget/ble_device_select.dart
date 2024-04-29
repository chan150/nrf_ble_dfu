import 'package:flutter/material.dart';

class BleDeviceSelect extends StatelessWidget {
  const BleDeviceSelect({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: stream builder ~ list ~ auto scan 가능한지 테스트
    return ListView(
      shrinkWrap: true,
      children: [
        Text('Ble Device List'),
      ],
    );
  }
}

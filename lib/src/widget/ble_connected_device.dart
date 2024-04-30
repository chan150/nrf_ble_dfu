import 'dart:async';

import 'package:flutter/material.dart';

class BleConnectedDevice extends StatefulWidget {
  const BleConnectedDevice({super.key});

  @override
  State<BleConnectedDevice> createState() => _BleConnectedDeviceState();
}

class _BleConnectedDeviceState extends State<BleConnectedDevice> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Stream.periodic(
      const Duration(milliseconds: 100),
      (i) => i,
    ).listen((_) {

    });
    // FlutterBluePlus.connectedDevices
  }

  @override
  void dispose() {
    super.dispose();
    _subscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

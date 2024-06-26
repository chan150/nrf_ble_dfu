import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class DfuFileSelect extends StatelessObserverWidget {
  const DfuFileSelect({super.key, this.builder});

  final Widget Function(String?)? builder;

  @override
  Widget build(BuildContext context) {
    final builder = this.builder ?? (path) => Text(path ?? 'Select firmware');
    return InkWell(
      onTap: NrfBleDfu().selectDfu,
      child: builder(NrfBleDfu().file.path),
    );
  }
}

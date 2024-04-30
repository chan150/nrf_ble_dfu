import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class DfuProgress extends StatelessObserverWidget {
  const DfuProgress({super.key});

  @override
  Widget build(BuildContext context) {
    if (NrfBleDfu().progress.fileSize == null) return const SizedBox();
    if (NrfBleDfu().progress.completedSize == null) return const SizedBox();
    final fileSize = NrfBleDfu().progress.fileSize ?? 1;
    final completedSize = NrfBleDfu().progress.completedSize ?? 0;
    return LinearProgressIndicator(value: completedSize / fileSize);
  }
}

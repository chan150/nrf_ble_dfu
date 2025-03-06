import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class DfuProgress extends StatelessObserverWidget {
  const DfuProgress({super.key, this.progress});

  final DfuProgressState? progress;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress ?? NrfBleDfu().progress;
    if (progress.fileSize == null) return const SizedBox();
    if (progress.completedSize == null) return const SizedBox();
    final fileSize = progress.fileSize ?? 1;
    final completedSize = progress.completedSize ?? 0;
    return LinearProgressIndicator(value: completedSize / fileSize);
  }
}

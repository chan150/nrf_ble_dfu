import 'package:flutter/material.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';

class DfuProgress extends StatelessWidget {
  const DfuProgress({super.key});

  @override
  Widget build(BuildContext context) {
    final dfu = NrfBleDfu();
    return ListenableBuilder(
      listenable: dfu.progress,
      builder: (context, _) {
        if (dfu.progress.fileSize == null) return const SizedBox();
        if (dfu.progress.completedSize == null) return const SizedBox();
        final fileSize = dfu.progress.fileSize ?? 1;
        final completedSize = dfu.progress.completedSize ?? 0;
        return LinearProgressIndicator(value: completedSize / fileSize);
      },
    );
  }
}

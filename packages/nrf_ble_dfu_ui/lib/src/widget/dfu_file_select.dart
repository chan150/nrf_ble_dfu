import 'package:flutter/material.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class DfuFileSelect extends StatelessWidget {
  const DfuFileSelect({super.key, this.builder});

  final Widget Function(String?)? builder;

  @override
  Widget build(BuildContext context) {
    final displayBuilder = builder ?? (path) => Text(path ?? 'Select firmware');
    final dfu = NrfBleDfu();

    return ListenableBuilder(
      listenable: dfu.file,
      builder: (context, _) {
        return InkWell(
          onTap: () async {
            final result = await FilePicker.pickFiles();
            final path = result?.files.singleOrNull?.path;
            if (path != null) {
              final bytes = await File(path).readAsBytes();
              final tempDir = await getTemporaryDirectory();
              await dfu.setFirmwareFile(path, bytes, tempDir.path);
            }
          },
          child: displayBuilder(dfu.file.path),
        );
      },
    );
  }
}

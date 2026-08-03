library nrf_ble_dfu_ui;

import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';
import 'src/dfu_ui_manager.dart';

export 'package:nrf_ble_dfu/nrf_ble_dfu.dart';
export 'src/widget/widget.dart';
export 'src/dfu_ui_manager.dart';

Future<void> initNrfBleDfuForFlutter() async {
  // 1. Initialize the Core package
  NrfBleDfu().initialize();

  // 2. Initialize the UI preference/persistence manager
  await DfuUiManager().initialize();
}

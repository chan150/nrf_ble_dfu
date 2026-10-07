# NRF BLE DFU UI Package

A Flutter package providing ready-to-use widgets, SQLite persistence (for update history and real-time logs), and SharedPreferences preset management, designed as a wrapper around the core library `nrf_ble_dfu`.

## Quick start

One call flashes a device over BLE, whichever protocol it speaks:

```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';

// Pick a scan result. dfuProtocolOf(result) says which protocol it
// advertises; smpFirst / findNordicBootloader help choose one.
final ScanResult target = FlutterBluePlus.lastScanResults.first;
final bytes = await File(path).readAsBytes(); // .zip (Nordic) or .bin (Zephyr)

await flashOverBle(
  target,
  bytes,
  onProgress: (f) => print('${(f * 100).floor()}%'),
  onLog: print,
);
```

For Nordic it enters the bootloader and rescans for it when needed; for
Zephyr it uploads, confirms and resets. Pass `protocol:` when the device does
not advertise its service, and `confirm: false` for a test boot that MCUboot
reverts unless you confirm after reboot. Everything below is the lower-level
pieces this call is built from.

## Features
- **Flutter UI Widgets**: Select device, select firmware files, preset configuration list, automatic scan/update controls, real-time log terminal, and update history.
- **Robust Persistence**: Logs and history are saved inside local SQLite storage automatically. Custom DFU presets are persisted via SharedPreferences.
- **Transport Adapters**: Adapts `flutter_blue_plus` to both of the core's transport seams: `FbpDevice` / `FbpCharacteristic` for Nordic Secure DFU, `SmpManager` for MCUmgr SMP (Zephyr / MCUboot).
- **Advertisement Matching**: Tells the two protocols apart from a scan result, so one scanner can feed either updater.

## Layout

```
lib/
  nrf_ble_dfu_ui.dart         single export
  src/
    flash_over_ble.dart       flashOverBle: scan result + bytes -> device running the new firmware
    fbp_adapters.dart         FbpDevice / FbpCharacteristic: DfuDevice over flutter_blue_plus (Nordic)
    smp_manager.dart          SmpManager: SmpTransport over flutter_blue_plus (Zephyr SMP, CBOR framing)
    dfu_advertisement.dart    nordicDfuService / zephyrSmpService, advertisesSmp, smpFirst, findNordicBootloader
    dfu_ui_manager.dart       DfuUiManager: wires the core to logs, history and presets
    auto_dfu_controller.dart  scan-and-update automation
    database/                 SQLite logger and history
    widget/                   device, firmware, preset, log and history widgets
test/                         advertisement matching and widget tests
example/                      sample app
```

Both protocol cores come from `nrf_ble_dfu`; this package adds nothing protocol-specific beyond the two adapters.

## Installation

Add `nrf_ble_dfu_ui` to your `pubspec.yaml` dependencies:
```yaml
dependencies:
  nrf_ble_dfu_ui:
    path: path/to/packages/nrf_ble_dfu_ui # Or version from pub.dev once published
```

## Initialization

You **must** initialize the Flutter UI adapters during your application's main entry point startup:

```dart
import 'package:flutter/material.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize and bind all SQLite databases and Bluetooth adapters
  await initNrfBleDfuForFlutter();

  runApp(const MyApp());
}
```

## UI Components

This package exports several ready-made widgets to build a comprehensive DFU dashboard:

- `DfuFileSelect`: Opens a system file picker to select a firmware zip package.
- `BleEntrySetup`: Sets up UUIDs, entry packets, target device names, and scan filters.
- `AutoBleDfu`: Toggles automatic DFU scanning and updates for nearby devices matching specified names.
- `BleConnectedDevice`: Lists connected Bluetooth devices.
- `DfuProgress`: Renders the upload progress bar, percentages, speed, and status description.
- `BleDeviceSelect`: Manually scan and connect to local Bluetooth devices.
- `LogConsole`: Displays raw DFU protocol and device log history in a terminal console view.

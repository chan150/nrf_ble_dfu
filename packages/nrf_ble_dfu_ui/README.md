# NRF BLE DFU UI Package

A Flutter package providing ready-to-use widgets, SQLite persistence (for update history and real-time logs), and SharedPreferences preset management, designed as a wrapper around the pure Dart core library `nrf_ble_dfu`.

## Features
- **Flutter UI Widgets**: Select device, select firmware files, preset configuration list, automatic scan/update controls, real-time log terminal, and update history.
- **Robust Persistence**: Logs and history are saved inside local SQLite storage automatically. Custom DFU presets are persisted via SharedPreferences.
- **Platform Agnostic Adapters**: Adapts `flutter_blue_plus` to the core's abstract BLE interfaces.

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

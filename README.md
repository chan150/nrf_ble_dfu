# NRF BLE DFU (Core)

Nordic BLE DFU (Device Firmware Update) protocol implementation for Flutter. This is the core library: the DFU transception logic, the protocol state machines, and the Bluetooth transport, built on `flutter_blue_plus`.

> Version 1.0.0 was a pure Dart core that reached Bluetooth through injected adapters. 2.0.0 drops those ports and depends on Flutter and `flutter_blue_plus` directly, so upgrading from 1.0.0 means removing the adapters passed to `initialize()`.

If you are developing a Flutter application and need ready-to-use UI widgets, state-managed components, SQLite logs/history databases, and automated updates, please use [nrf_ble_dfu_ui](packages/nrf_ble_dfu_ui/README.md).

## Installation

Add `nrf_ble_dfu` to your `pubspec.yaml`:
```yaml
dependencies:
  nrf_ble_dfu: ^2.0.0
```

## Decoupled Architecture

The repository is structured as a multi-package workspace:
- **`nrf_ble_dfu` (Root)**: The core package, containing the protocol transception and the state machines.
- **`nrf_ble_dfu_ui` (`packages/nrf_ble_dfu_ui`)**: The Flutter UI widget wrapper, implementing the SQLite database logger and SharedPreferences preset management.

---

## Example (Flutter UI Integration)
Make sure to initialize the library with the Flutter UI package at app startup:
```dart
import 'package:flutter/material.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Required: Bind the Flutter Bluetooth Low Energy adapters and UI managers
  await initNrfBleDfuForFlutter();
  
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: const [
          DfuFileSelect(),
          Divider(),
          BleEntrySetup(),
          Divider(),
          AutoBleDfu(),
          Divider(),
          BleConnectedDevice(),
          DfuProgress(),
          Divider(),
          BleDeviceSelect(),
        ],
      ),
    );
  }
}
```
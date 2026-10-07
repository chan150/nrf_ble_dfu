# NRF BLE DFU (Core)

Two BLE firmware-update protocols in pure Dart: Nordic Secure DFU (nRF5 SDK bootloaders) and MCUmgr SMP (Zephyr / MCUboot). It declares no Flutter dependency and contains no Bluetooth stack; you hand it a `DfuDevice` (Nordic) or an `SmpTransport` (SMP), and `FirmwareUpdater` drives either the same way once `DfuProtocol` has told them apart.

> Upgrading from 1.0.0: the ports are narrower. `DfuBleAdapter`, `DfuBleService` and `DfuScanResult` are gone because the core no longer scans, and so are the storage, path and database adapters, so `initialize()` takes no arguments. Implement `DfuDevice` and `DfuCharacteristic`, or take `FbpDevice` and `FbpCharacteristic` from `nrf_ble_dfu_ui`.

If you are developing a Flutter application and need ready-to-use UI widgets, state-managed components, SQLite logs/history databases, and automated updates, please use [nrf_ble_dfu_ui](packages/nrf_ble_dfu_ui/README.md).

## Installation

Add `nrf_ble_dfu` to your `pubspec.yaml`:
```yaml
dependencies:
  nrf_ble_dfu: ^2.0.0
```

## Layout

```
lib/
  nrf_ble_dfu.dart            single export
  src/
    nrf_ble_dfu.dart          NrfBleDfu: Nordic Secure DFU core
    ble.dart                  DfuDevice / DfuCharacteristic, the Nordic transport seam
    dfu_service_uuids.dart    DfuProtocol {nordic, zephyr}: service UUIDs, advertisement matching
    firmware_updater.dart     FirmwareUpdater + NordicFirmwareUpdater / SmpFirmwareUpdater
    zephyr/
      smp_header.dart         SMP frame header, groups, commands
      smp_transport.dart      SmpTransport, the SMP transport seam; smpChunkSize
      smp_dfu_manager.dart    SmpDfuManager: echo, list, upload, test, confirm, reset
    enum/ extension/ state/   Nordic state model
test/                         protocol tests, no Bluetooth needed
packages/nrf_ble_dfu_ui/      Flutter layer on flutter_blue_plus
  lib/src/
    fbp_adapters.dart         FbpDevice / FbpCharacteristic (DfuDevice over flutter_blue_plus)
    smp_manager.dart          SmpManager (SmpTransport over flutter_blue_plus)
    dfu_advertisement.dart    which scan results are flashable, per protocol
    dfu_ui_manager.dart, auto_dfu_controller.dart, widget/, database/
```

- **`nrf_ble_dfu` (root)**: the pure Dart cores and the two interfaces Bluetooth arrives through. Nothing here opens a connection.
- **`nrf_ble_dfu_ui`**: the flutter_blue_plus adapters for both protocols, plus UI widgets, the SQLite history database and SharedPreferences presets.

Consumers that drive both protocols without Flutter (a CLI, loopback tests) live in the sibling `nrf_ble_dfu_zephyr` repository.

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
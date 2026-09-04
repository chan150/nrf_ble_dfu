## 2.0.0
Still a pure Dart core, but a much smaller one than 1.0.0, and the ports have
changed shape.

* **Breaking Change**: Bluetooth arrives through two interfaces, `DfuDevice` and `DfuCharacteristic`, replacing 1.0.0's `DfuBleAdapter` / `DfuBleDevice` / `DfuBleService` / `DfuBleCharacteristic` / `DfuScanResult`. Pass a `DfuDevice` to `updateFirmware` and `enterDfuMode`. `nrf_ble_dfu_ui` implements both over flutter_blue_plus as `FbpDevice` and `FbpCharacteristic`.
* **Breaking Change**: Scanning is gone from the core, along with the `DfuBleAdapter` that served it. Finding a device is the caller's job; `nrf_ble_dfu_ui` does it in `AutoDfuController`, which also owns `autoDfuTargets`, `autoDfuFinished` and `retryDfu`.
* **Breaking Change**: `initialize()` takes no arguments. The `DfuStorageAdapter`, `DfuPathAdapter` and `DfuDatabaseAdapter` ports are gone; preset storage and the history database live in `nrf_ble_dfu_ui`, which drives them off the existing `onLog`, `onHistory` and `onHistoryClear` streams.
* **Breaking Change**: State objects extend `DfuListenable` instead of being mobx stores, so there is no codegen and no `*.g.dart`. Wrap one in `listenableOf()` from `nrf_ble_dfu_ui` to feed a `ListenableBuilder`.
* Packet writes are sized from the negotiated ATT MTU rather than a fixed 20 bytes.
* Writes are paced by packet receipt notifications, and every receipt is checked against both the acknowledged offset and the CRC.
* Fixed `dfuCrc32` returning a negative value, which had made any CRC comparison impossible.

## 1.0.0
* **Breaking Change**: Restructured project into a multi-package repository.
* **Breaking Change**: The root package `nrf_ble_dfu` is now a pure Dart core package (no longer depends on Flutter SDK).
* **Breaking Change**: Relocated all UI widgets, FBP adapters, SQLite persistence, and SharedPreferences storage to the new Flutter package `packages/nrf_ble_dfu_ui`.

## 0.0.24
* Implement SQLite for update history and logs.
* Add Log Console UI for real-time monitoring.

## 0.0.23
* Add separate Auto Update toggle.
* Fix FilePicker compilation error.
* Refine auto scan and update logic.

## 0.0.22
* Fix FilePicker usage and dependency constraints.
* Fix analysis warnings.

## 0.0.21
* Add automated scan and update history system.
* Implement persistent history dialog and retry logic.

## 0.0.20
* Use `flutter_blue_plus_windows` for Windows support.

## 0.0.19
* Fix Bluetooth connection signature mismatch.
* Standardize on `flutter_blue_plus`.
* Update dependency constraints.

## 0.0.14
* Minor fixes and updates.

## 0.0.13
* Fix typos in `nrf_dfu_op_t`. 

## 0.0.12
* Enable to use firmware binary instead of firmware file path. 
* Fix bug w.r.t. dfu failure in android device.

## 0.0.11
* Store entry setup into shared preference.

## 0.0.9
* Run dart formatter.

## 0.0.8
* Add specified-platform in `pub.dev`.

## 0.0.7
* Fix list view scroll error in Android.

## 0.0.6
* Make manager to execute auto DFU. 

## 0.0.5
* Grant android support. 

## 0.0.4
* Add button to mark completed devices.

## 0.0.3
* Does not auto DFU for finished devices.

## 0.0.2
* Add automated dfu mode entry.

## 0.0.1
* Initial release.

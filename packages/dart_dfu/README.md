# dart_dfu

One command line tool for both firmware update protocols in use here: Nordic
DFU for nRF5 SDK bootloaders, and MCUmgr SMP for Zephyr and MCUboot.

Nothing in it depends on Flutter. Both protocol cores live in `nrf_ble_dfu`, are
pure Dart, and reach the device through interfaces the caller supplies, which is what lets a terminal tool drive the same code an app
does.

## Usage

```
dart_dfu <nordic|zephyr> <command> [arguments]
```

Global flags:

| Flag | Effect |
|------|--------|
| `-v`, `--verbose` | Protocol diagnostics to stderr. stdout stays clean for piping. |
| `--loopback` | Run against an in-memory device. No hardware needed. |

### Nordic — nRF5 SDK bootloaders

```
dart_dfu nordic enter                     # reboot an app-mode device into DFU
dart_dfu nordic upload <package.zip>      # flash a DFU package
```

`enter` writes the entry packet to the device's application control point,
which reboots it into the bootloader. Skip it if the device is already
advertising in DFU mode.

`upload` takes the `.zip` the Nordic tooling produces. The init packet and the
image inside it are transferred one after the other, so the percentage fills
twice.

### Zephyr — MCUboot

```
dart_dfu zephyr list                      # images on the device, with slots
dart_dfu zephyr upload <image.bin> [--confirm]
dart_dfu zephyr reset                     # reboot
```

`--confirm` marks the image confirmed as it is written. Without it the image is
staged and MCUboot decides on the next boot.

### Trying it without hardware

```
dart_dfu --loopback zephyr upload image.bin
dart_dfu --loopback nordic upload package.zip
```

The loopback devices are not simulators. They answer only what the protocol
requires and reject a frame that does not continue where the last one stopped,
the way a real device does, so a transfer that runs to completion has proven
its offsets and CRCs lined up. They exist to exercise the protocol logic in
tests, and to let the tool be run before a transport exists.

## Connecting real hardware

Two functions in `bin/dart_dfu.dart` know that hardware exists, and only those.
They are deliberately the same shape:

| Protocol | Function | Implement |
|----------|----------|-----------|
| Nordic | `openNordicDevice()` | `DfuDevice` and `DfuCharacteristic` from `nrf_ble_dfu` |
| Zephyr | `openZephyrTransport()` | `SmpTransport` from `nrf_ble_dfu` |

Return your implementation from the matching function. Nothing above those
lines changes.

`SmpTransport` is two members, `mtu` and `sendRequest`. `DfuDevice` and
`DfuCharacteristic` are nine between them (five and four), because Nordic DFU drives two GATT
characteristics directly rather than exchanging framed messages. For a working
Bluetooth implementation of either, see `SmpManager` in `nrf_ble_dfu_ui` and
`nrf_ble_dfu_ui`.

## What is not unified

The two protocols reach different bootloaders and share no wire format, so
their commands stay separate. `nordic` has no `list` because Nordic DFU has no
image inventory to ask for; `zephyr` has no `enter` because MCUmgr runs in the
application. A verb only one protocol has is absent from the other rather than
faked.

What is unified: flashing. Both `upload` verbs run through `FirmwareUpdater`
from `nrf_ble_dfu` (`NordicFirmwareUpdater`, `SmpFirmwareUpdater`), which is
also what an app should hold once it has told the two apart by `DfuProtocol`.
The command shape, how progress is drawn, where diagnostics go, and the one
function per protocol where a transport gets wired up are the same on purpose.

## Layout

```
nrf_ble_dfu/            pure Dart      Nordic DFU protocol
dart_dfu/               this tool
flutter_dfu/            Flutter app    both cores, with a UI
```

`nrf_ble_dfu` lives in its own repository, resolved by path the way every
sibling package in the mono repository is. Building this outside a checkout of
the mono repository needs that override changed.

import 'dart:io';
import 'dart:typed_data';

import 'ble.dart';
import 'dfu_service_uuids.dart';
import 'nrf_ble_dfu.dart';
import 'zephyr/smp_dfu_manager.dart';
import 'zephyr/smp_transport.dart';

/// One firmware update, whichever protocol the target speaks.
///
/// The two cores take different links ([DfuDevice] against a Nordic
/// bootloader, [SmpTransport] against an MCUmgr application) and different
/// payloads (a DFU .zip package, a signed .bin image), so constructing one is
/// still protocol-specific. Running it is not: a caller that has told the two
/// apart by [DfuProtocol] drives both the same way.
abstract class FirmwareUpdater {
  DfuProtocol get protocol;

  /// Flashes [firmware] and completes once the device has accepted all of it.
  ///
  /// [onProgress] is given a fraction from 0 to 1. For Nordic it fills twice,
  /// once for the init packet and once for the image, since those are two
  /// transfers on the wire.
  Future<void> flash(
    List<int> firmware, {
    void Function(double fraction)? onProgress,
  });
}

/// Flashes a Nordic Secure DFU package (.zip holding a .dat and a .bin).
class NordicFirmwareUpdater implements FirmwareUpdater {
  /// [packageName] is only what the core records in its history; the bytes
  /// come from [flash].
  NordicFirmwareUpdater(
    this.device, {
    NrfBleDfu? core,
    this.packageName = 'package.zip',
  }) : core = core ?? (NrfBleDfu()..initialize());

  final DfuDevice device;
  final NrfBleDfu core;
  final String packageName;

  @override
  DfuProtocol get protocol => DfuProtocol.nordic;

  @override
  Future<void> flash(
    List<int> firmware, {
    void Function(double fraction)? onProgress,
  }) async {
    final unpacked = Directory.systemTemp.createTempSync('nrf_ble_dfu');

    void report() {
      final total = core.progress.fileSize;
      final done = core.progress.completedSize;
      if (total == null || done == null || total == 0) return;
      onProgress!(done / total);
    }

    if (onProgress != null) core.progress.addListener(report);
    try {
      await core.setFirmwareFile(packageName, firmware, unpacked.path);
      await core.updateFirmware(device);
    } finally {
      core.progress.removeListener(report);
      unpacked.deleteSync(recursive: true);
    }
  }
}

/// Flashes a signed MCUboot image (.bin) over MCUmgr SMP.
///
/// Upload only, which is all the two protocols have in common. Marking the
/// image to test or confirm and rebooting into it stay on [SmpDfuManager],
/// since a Nordic bootloader does those on its own.
class SmpFirmwareUpdater implements FirmwareUpdater {
  SmpFirmwareUpdater(
    this.transport, {
    this.confirm = false,
    void Function(String message)? onLog,
  }) : manager = SmpDfuManager(transport, onLog: onLog);

  final SmpTransport transport;
  final SmpDfuManager manager;

  /// Whether the image is marked confirmed as it is written, so the device
  /// keeps it after the first boot without a separate confirm.
  final bool confirm;

  @override
  DfuProtocol get protocol => DfuProtocol.zephyr;

  @override
  Future<void> flash(
    List<int> firmware, {
    void Function(double fraction)? onProgress,
  }) =>
      manager.uploadImage(
        firmware is Uint8List ? firmware : Uint8List.fromList(firmware),
        confirm: confirm,
        onProgress: onProgress,
      );
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

import 'dfu_advertisement.dart';
import 'fbp_adapters.dart';
import 'smp_manager.dart';

/// Flashes [firmware] onto the device behind [target], whichever protocol it
/// speaks, and leaves it booting the new image.
///
/// This is the whole job in one call. It tells the protocol from the
/// advertisement (or takes [protocol] when the advertisement does not say),
/// connects, negotiates the MTU, and then:
///
/// * **Nordic** (a `.zip` package): if [target] is still the application, it
///   is sent into its bootloader and the bootloader is found by rescanning
///   for up to [bootloaderTimeout]; then the package is transferred. The
///   bootloader reboots into the application on its own. [onProgress] fills
///   twice, once for the init packet and once for the image.
/// * **Zephyr / MCUboot** (a signed `.bin` image): the image is uploaded,
///   marked [confirm]ed (permanent) or merely pending for a test boot, and the
///   device is reset so it boots the new image. With `confirm: false` the app
///   must call [SmpDfuManager.confirmImage] after the next boot or MCUboot
///   reverts to the old image.
///
/// Throws [ArgumentError] when the protocol cannot be determined, and
/// whatever the transport throws when the device goes away mid-transfer.
Future<void> flashOverBle(
  ScanResult target,
  List<int> firmware, {
  DfuProtocol? protocol,
  void Function(double fraction)? onProgress,
  void Function(String message)? onLog,
  bool confirm = true,
  Duration bootloaderTimeout = const Duration(seconds: 15),
  String? nameFallback,
  NrfBleDfu? core,
}) async {
  final which = protocol ?? dfuProtocolOf(target);
  if (which == null) {
    throw ArgumentError(
        '${target.device.remoteId} advertises neither Nordic DFU nor SMP; '
        'pass protocol: explicitly.');
  }
  switch (which) {
    case DfuProtocol.nordic:
      await _flashNordic(target, firmware,
          onProgress: onProgress,
          onLog: onLog,
          bootloaderTimeout: bootloaderTimeout,
          nameFallback: nameFallback,
          core: core);
    case DfuProtocol.zephyr:
      await _flashZephyr(target, firmware,
          onProgress: onProgress, onLog: onLog, confirm: confirm);
  }
}

Future<void> _flashNordic(
  ScanResult target,
  List<int> firmware, {
  required void Function(double)? onProgress,
  required void Function(String)? onLog,
  required Duration bootloaderTimeout,
  required String? nameFallback,
  required NrfBleDfu? core,
}) async {
  final dfu = core ?? (NrfBleDfu()..initialize());
  StreamSubscription<LogEntry>? logs;
  if (onLog != null) logs = dfu.onLog.listen((e) => onLog(e.message));
  try {
    var bootloader = target.device;
    if (!isNordicBootloader(target)) {
      onLog?.call('Sending ${target.device.remoteId} into its bootloader');
      final app = FbpDevice(target.device);
      await app.connect();
      await _requestMtu(target.device);
      await dfu.enterDfuMode(app);
      bootloader = await _findBootloader(target, bootloaderTimeout, nameFallback);
    }
    final device = FbpDevice(bootloader);
    await device.connect();
    await _requestMtu(bootloader);
    await NordicFirmwareUpdater(device, core: dfu)
        .flash(firmware, onProgress: onProgress);
  } finally {
    await logs?.cancel();
  }
}

/// The bootloader advertises under the application's address plus one (or a
/// name on iOS/macOS, which hide addresses), so rescan until it shows up.
Future<BluetoothDevice> _findBootloader(
    ScanResult app, Duration timeout, String? nameFallback) async {
  await FlutterBluePlus.startScan(timeout: timeout);
  try {
    final found = await FlutterBluePlus.scanResults
        .map((results) => findNordicBootloader(results, app.device.remoteId.str,
            nameFallback: nameFallback))
        .firstWhere((r) => r != null)
        .timeout(timeout,
            onTimeout: () => throw TimeoutException(
                'Bootloader of ${app.device.remoteId} did not advertise',
                timeout));
    return found!.device;
  } finally {
    await FlutterBluePlus.stopScan();
  }
}

Future<void> _flashZephyr(
  ScanResult target,
  List<int> firmware, {
  required void Function(double)? onProgress,
  required void Function(String)? onLog,
  required bool confirm,
}) async {
  final transport = SmpManager(target.device, onLog: onLog);
  await transport.connect();
  try {
    final updater = SmpFirmwareUpdater(transport, confirm: confirm, onLog: onLog);
    await updater.flash(firmware, onProgress: onProgress);
    if (!confirm) {
      // Pending-only upload: mark the new slot for a test boot. Read the hash
      // back rather than computing it, since the device is the authority on
      // what landed.
      final images = await updater.manager.listImages();
      final staged = images.where((i) => !i.active).toList();
      if (staged.isEmpty) throw StateError('No staged image after upload');
      await updater.manager.testImage(staged.first.hash);
    }
    onLog?.call('Resetting into the new image');
    try {
      await updater.manager.reset();
    } catch (_) {
      // The device drops the link as it reboots; that is the expected end.
    }
  } finally {
    await transport.disconnect();
  }
}

/// flutter_blue_plus only negotiates on Android; elsewhere the OS has already
/// picked the MTU and asking throws.
Future<void> _requestMtu(BluetoothDevice device) async {
  if (Platform.isAndroid) await device.requestMtu(247);
}

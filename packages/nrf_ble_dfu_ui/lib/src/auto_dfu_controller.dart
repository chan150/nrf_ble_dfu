import 'package:flutter_blue_rs/flutter_blue_plus.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';
import 'package:path/path.dart';

import 'dfu_advertisement.dart';
import 'fbp_adapters.dart';

/// Scans for devices and flashes them without being asked to.
///
/// This is app policy, not protocol: which advertised names count as targets,
/// how long a failed device is left alone, and when a device is considered
/// already done. It drives [NrfBleDfu.updateFirmware], which stays in the core
/// and knows nothing about scanning.
class AutoDfuController {
  factory AutoDfuController() => _instance;
  static final _instance = AutoDfuController._internal();
  AutoDfuController._internal();

  final _dfu = NrfBleDfu();

  /// Devices currently worth flashing, and ones already done.
  final Set<BluetoothDevice> autoDfuTargets = {};
  final Set<BluetoothDevice> autoDfuFinished = {};

  StreamSubscription<void>? _historyClearSubscription;

  /// Clearing the history means nothing has been flashed yet, so forget which
  /// devices were finished. The core announces it on a stream it already had.
  void listenForHistoryClear() {
    _historyClearSubscription ??= _dfu.onHistoryClear.listen((_) {
      autoDfuFinished.clear();
      _dfu.setup.notify();
    });
  }

  /// Lets a device be flashed again after it was marked done.
  void retryDfu(String remoteId) {
    _dfu.setup.updatedMacs.remove(remoteId);
    autoDfuFinished.removeWhere((d) => d.remoteId.str == remoteId);
    _dfu.setup.notify();
  }

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isAutoDfuRunning = false;
  Timer? _autoScanTimer;

  final Map<String, DateTime> _failedCooldown = {};

  bool _isTarget(ScanResult s) {
    final name = s.device.platformName;
    final id = s.device.remoteId.str;
    final cooldown = _failedCooldown[id];
    return (RegExp(_dfu.autoEntryDeviceName).hasMatch(name) ||
            RegExp(_dfu.autoDfuDeviceName).hasMatch(name)) &&
        !_isDuplicate(name, id) &&
        !autoDfuFinished.any((d) => d.remoteId.str == id) &&
        (cooldown == null || DateTime.now().isAfter(cooldown));
  }

  bool _isDuplicate(String name, String remoteId) {
    final fwName = _dfu.file.path != null ? basename(_dfu.file.path!) : '';
    final serial = _dfu.serialNumberOf(name);
    return _dfu.setup.history.any((h) =>
        h.status == 'success' &&
        h.firmwareName == fwName &&
        h.remoteId == remoteId &&
        h.serialNumber == serial);
  }

  Future<void> autoDfu() async {
    // Handed straight to onPressed, where a throw goes unhandled: log what
    // is missing instead.
    final missing = [
      if (_dfu.file.datPath == null) 'init packet (.dat)',
      if (_dfu.file.binPath == null) 'image (.bin)',
    ];
    if (missing.isNotEmpty) {
      _dfu.log('Select a firmware package first: no ${missing.join(' and ')}.',
          level: 'WARN');
      return;
    }
    if (_isAutoDfuRunning) return;

    if (!FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        continuousUpdates: true,
      );
    }
  }

  Future<void> _processAutoDfu(List<ScanResult> results) async {
    if (_isAutoDfuRunning) return;
    if (!_dfu.setup.isAutoUpdateEnabled) return;

    final candidates = results.where(_isTarget).toList();

    if (candidates.isEmpty) return;

    final selectedScan = candidates.firstWhere(
        (s) => RegExp(_dfu.autoDfuDeviceName).hasMatch(s.device.platformName),
        orElse: () => candidates.first);

    _isAutoDfuRunning = true;
    final device = selectedScan.device;
    final remoteId = device.remoteId.str;
    final deviceName = device.platformName;
    final isAlreadyInDfu = RegExp(_dfu.autoDfuDeviceName).hasMatch(deviceName);

    try {
      if (!isAlreadyInDfu) {
        _dfu.log('Target found: $deviceName ($remoteId). Connecting...');
        await device.connect(timeout: const Duration(seconds: 3));

        try {
          await device.requestMtu(247);
        } catch (_) {}

        _dfu.log('Entering DFU mode...');
        await _dfu.enterDfuMode(FbpDevice(device));

        _dfu.log('Waiting for the bootloader to advertise...');
        BluetoothDevice? dfuDevice;
        final timeout = DateTime.now().add(const Duration(seconds: 15));

        await FlutterBluePlus.startScan(continuousUpdates: true);

        while (DateTime.now().isBefore(timeout)) {
          final currentResults = await FlutterBluePlus.scanResults.first;
          // The advertised DFU service identifies a bootloader, not its name;
          // its address may also have shifted on reboot.
          dfuDevice = findNordicBootloader(
            currentResults,
            device.remoteId.str,
            nameFallback: _dfu.autoDfuDeviceName,
          )?.device;
          if (dfuDevice != null) break;
          await Future.delayed(const Duration(milliseconds: 200));
        }

        if (dfuDevice == null) {
          throw Exception('DFU device not found after entry');
        }

        _dfu.log('DFU device found. Connecting for firmware update...');
        await dfuDevice.connect(timeout: const Duration(seconds: 3));
        try {
          await dfuDevice.requestMtu(247);
        } catch (_) {}

        await _dfu.updateFirmware(FbpDevice(dfuDevice));
      } else {
        _dfu.log('Target already in DFU mode: $deviceName ($remoteId). Connecting for update...');
        await device.connect(timeout: const Duration(seconds: 3));
        try {
          await device.requestMtu(247);
        } catch (_) {}

        await _dfu.updateFirmware(FbpDevice(device));
      }

      _dfu.addHistoryEntry(
        remoteId: remoteId,
        deviceName: deviceName,
        status: 'success',
      );
      autoDfuFinished.add(device);
      _dfu.setup.notify();
    } catch (e) {
      _dfu.log('Auto DFU error: $e', level: 'ERROR');
      _failedCooldown[remoteId] =
          DateTime.now().add(const Duration(seconds: 5));
      _dfu.addHistoryEntry(
        remoteId: remoteId,
        deviceName: deviceName,
        status: 'failed',
        note: e.toString(),
      );
    } finally {
      _isAutoDfuRunning = false;
      if (_dfu.setup.isAutoScanEnabled || _dfu.setup.isAutoUpdateEnabled) {
        _startAutoScan();
      }
    }
  }

  void _stopAutoScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
  }

  void _startAutoScan() {
    _stopAutoScan();
    if (!_dfu.setup.isAutoScanEnabled && !_dfu.setup.isAutoUpdateEnabled) return;

    FlutterBluePlus.startScan(continuousUpdates: true);

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      final filtered = results.where(_isTarget).map((s) => s.device).toList();

      autoDfuTargets.clear();
      autoDfuTargets.addAll(filtered);
      _dfu.setup.notify();

      if (_dfu.setup.isAutoUpdateEnabled) {
        _processAutoDfu(results);
      }
    });

    _autoScanTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!FlutterBluePlus.isScanningNow) {
        FlutterBluePlus.startScan(continuousUpdates: true);
      }
    });
  }

  void toggleAutoScan(bool enable) {
    _dfu.setup.isAutoScanEnabled = enable;
    _dfu.setup.notify();
    _checkAutoScanLoop();
  }

  void toggleAutoUpdate(bool enable) {
    _dfu.setup.isAutoUpdateEnabled = enable;
    _dfu.setup.notify();
    _checkAutoScanLoop();
  }

  void _checkAutoScanLoop() {
    final shouldRun = _dfu.setup.isAutoScanEnabled || _dfu.setup.isAutoUpdateEnabled;
    if (shouldRun) {
      _startAutoScan();
    } else {
      _stopAutoScan();
    }
  }

  Future<void> refresh() async {
    autoDfuTargets.clear();
    autoDfuFinished.clear();
    _dfu.setup.notify();
    // Handed straight to a button too: report a refused scan (usually the
    // adapter being off) rather than throw.
    try {
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan();
    } catch (e) {
      _dfu.log('Could not restart the scan: $e', level: 'WARN');
    }
  }
}

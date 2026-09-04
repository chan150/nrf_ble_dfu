import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';
import 'package:path/path.dart';

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

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isAutoDfuRunning = false;
  Timer? _autoScanTimer;

  final Map<String, DateTime> _failedCooldown = {};

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
    if (_dfu.file.datPath == null) throw Exception('dat file not found');
    if (_dfu.file.binPath == null) throw Exception('bin file not found');
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

    final candidates = results.where((s) {
      final name = s.device.platformName;
      final isApp = RegExp(_dfu.autoEntryDeviceName).hasMatch(name);
      final isDfu = RegExp(_dfu.autoDfuDeviceName).hasMatch(name);
      return (isApp || isDfu) &&
          !_isDuplicate(s.device.platformName, s.device.remoteId.str) &&
          !_dfu.setup.autoDfuFinished
              .any((d) => d.remoteId.str == s.device.remoteId.str);
    }).where((s) {
      final cooldown = _failedCooldown[s.device.remoteId.str];
      return cooldown == null || DateTime.now().isAfter(cooldown);
    }).toList();

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
        await device.connect(
            license: License.nonprofit, timeout: const Duration(seconds: 3));

        try {
          await device.requestMtu(247);
        } catch (_) {}

        _dfu.log('Entering DFU mode...');
        await _dfu.enterDfuMode(device);

        _dfu.log('Waiting for $_dfu.autoDfuDeviceName...');
        BluetoothDevice? dfuDevice;
        final timeout = DateTime.now().add(const Duration(seconds: 15));

        await FlutterBluePlus.startScan(continuousUpdates: true);

        while (DateTime.now().isBefore(timeout)) {
          final currentResults = await FlutterBluePlus.scanResults.first;
          dfuDevice = currentResults
              .where((s) =>
                  RegExp(_dfu.autoDfuDeviceName).hasMatch(s.device.platformName))
              .where((s) =>
                  s.device.remoteId.str == device.remoteId.str ||
                  s.device.platformName == _dfu.autoDfuDeviceName)
              .firstOrNull
              ?.device;
          if (dfuDevice != null) break;
          await Future.delayed(const Duration(milliseconds: 200));
        }

        if (dfuDevice == null) {
          throw Exception('DFU device not found after entry');
        }

        _dfu.log('DFU device found. Connecting for firmware update...');
        await dfuDevice.connect(
            license: License.nonprofit, timeout: const Duration(seconds: 3));
        try {
          await dfuDevice.requestMtu(247);
        } catch (_) {}

        await _dfu.updateFirmware(dfuDevice);
      } else {
        _dfu.log('Target already in DFU mode: $deviceName ($remoteId). Connecting for update...');
        await device.connect(
            license: License.nonprofit, timeout: const Duration(seconds: 3));
        try {
          await device.requestMtu(247);
        } catch (_) {}

        await _dfu.updateFirmware(device);
      }

      _dfu.addHistoryEntry(
        remoteId: remoteId,
        deviceName: deviceName,
        status: 'success',
      );
      _dfu.setup.autoDfuFinished.add(device);
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
      final filtered = results
          .where((s) {
            final name = s.device.platformName;
            final isApp = RegExp(_dfu.autoEntryDeviceName).hasMatch(name);
            final isDfu = RegExp(_dfu.autoDfuDeviceName).hasMatch(name);
            return (isApp || isDfu);
          })
          .where((s) =>
              !_isDuplicate(s.device.platformName, s.device.remoteId.str))
          .where((s) => !_dfu.setup.autoDfuFinished
              .any((d) => d.remoteId.str == s.device.remoteId.str))
          .where((s) {
            final cooldown = _failedCooldown[s.device.remoteId.str];
            return cooldown == null || DateTime.now().isAfter(cooldown);
          })
          .map((s) => s.device)
          .toList();

      _dfu.setup.autoDfuTargets.clear();
      _dfu.setup.autoDfuTargets.addAll(filtered);
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
    _dfu.setup.autoDfuTargets.clear();
    _dfu.setup.autoDfuFinished.clear();
    _dfu.setup.notify();
    await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan();
  }
}

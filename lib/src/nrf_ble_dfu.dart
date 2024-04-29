import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class NrfBleDfu {
  factory NrfBleDfu() => _instance;

  static final _instance = NrfBleDfu._internal();

  NrfBleDfu._internal() {
    FlutterBluePlus.setLogLevel(LogLevel.error);
  }

  final origin = BleDeviceState();
  final dfu = BleDeviceState();
  final file = DfuFileState();

  bool Function(ScanResult) originScanFn = (scanResult) => scanResult.device.remoteId.str == 'C6:D9:1F:BC:65:5B';
  bool Function(ScanResult) dfuScanFn = (scanResult) => scanResult.device.remoteId.str == 'C6:D9:1F:BC:65:5C';

  StreamSubscription? originSubscription;
  StreamSubscription? dfuSubscription;

  Future<void> selectDfu() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    file.path = result.paths.single;

    final tempDir = await getTemporaryDirectory();
    final outputPath = join(tempDir.path, "firmware_files");
    final outputDir = Directory(outputPath);
    await outputDir.create();
    if (!outputDir.existsSync()) return;
    file.outputPath = outputPath;

    await extractFileToDisk(file.path!, outputPath);
    final list = outputDir.listSync();

    file.datPath = list.where((e) => e.path.endsWith('dat')).singleOrNull?.path;
    file.binPath = list.where((e) => e.path.endsWith('bin')).singleOrNull?.path;
  }

  Future<void> setOriginDevice(ScanResult scanResult) async {
    if (origin.device != null) return;
    if(originScanFn(scanResult)){
      origin.device = scanResult.device;
      await origin.device?.connect();
    }
  }

  Future<void> setDfuDevice(ScanResult scanResult) async {
    if (dfu.device != null) return;
    if(dfuScanFn(scanResult)){
      dfu.device = scanResult.device;
      await dfu.device?.connect();
    }
  }

  Future<void> scan() async {
    const timeout = Duration(seconds: 3);
    await FlutterBluePlus.startScan(timeout: timeout);
    final subscription = FlutterBluePlus.scanResults.expand((e) => e).listen((scanResult) {
      setOriginDevice(scanResult);
      setOriginDevice(scanResult);
    });
    await Future.delayed(timeout);
  }

  Future<void> stop() async {}
}

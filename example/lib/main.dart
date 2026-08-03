import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the core library
  NrfBleDfu().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nrf_ble_dfu Core Example',
      theme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.blue),
      home: const DfuCoreScreen(),
    );
  }
}

class DfuCoreScreen extends StatefulWidget {
  const DfuCoreScreen({super.key});

  @override
  State<DfuCoreScreen> createState() => _DfuCoreScreenState();
}

class _DfuCoreScreenState extends State<DfuCoreScreen> {
  final _dfu = NrfBleDfu();
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  String? _firmwarePath;
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Request permissions on mobile platforms
    _requestPermissions();

    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
        });
      }
    });

    // Listen to scanning status
    FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) {
        setState(() {
          _isScanning = scanning;
        });
      }
    });
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }
  }

  Future<void> _pickFirmware() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = result?.files.singleOrNull?.path;
    if (path != null) {
      final bytes = await File(path).readAsBytes();
      final tempDir = await getTemporaryDirectory();
      await _dfu.setFirmwareFile(path, bytes, tempDir.path);
      setState(() {
        _firmwarePath = path;
      });
    }
  }

  void _startScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
  }

  void _scrollToBottom() {
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('nrf_ble_dfu Core Example')),
      body: Row(
        children: [
          // Left Side: DFU Actions & Scanner
          Expanded(
            flex: 3,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Firmware ZIP Selector Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Select Firmware ZIP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _firmwarePath ?? 'No file selected',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickFirmware,
                          icon: const Icon(Icons.file_open),
                          label: const Text('Pick Zip File'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Scanner Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '2. Scan & Connect Target',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: _isScanning ? _stopScan : _startScan,
                              icon: Icon(
                                _isScanning ? Icons.stop : Icons.play_arrow,
                              ),
                              color: _isScanning ? Colors.red : Colors.green,
                              tooltip: _isScanning ? 'Stop Scan' : 'Start Scan',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        if (_scanResults.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'No devices found yet.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _scanResults.length,
                          itemBuilder: (context, index) {
                            final item = _scanResults[index];
                            final name = item.device.platformName;
                            return ListTile(
                              dense: true,
                              title: Text(
                                name.isEmpty ? 'Unknown' : name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${item.device.remoteId.str} | RSSI: ${item.rssi}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      try {
                                        _dfu.log(
                                          'Connecting to ${item.device.remoteId.str}...',
                                        );
                                        await item.device.connect(
                                          license: License.nonprofit,
                                          timeout: const Duration(seconds: 5),
                                        );
                                        _dfu.log('Entering DFU mode...');
                                        await _dfu.enterDfuMode(item.device);
                                      } catch (e) {
                                        _dfu.log(
                                          'Failed to enter DFU mode: $e',
                                          level: 'ERROR',
                                        );
                                      }
                                    },
                                    child: const Text('Enter DFU'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      try {
                                        _dfu.log(
                                          'Connecting to DFU target: ${item.device.remoteId.str}...',
                                        );
                                        await item.device.connect(
                                          license: License.nonprofit,
                                          timeout: const Duration(seconds: 5),
                                        );
                                        _dfu.log('Starting firmware update...');
                                        await _dfu.updateFirmware(item.device);
                                      } catch (e) {
                                        _dfu.log(
                                          'DFU Update failed: $e',
                                          level: 'ERROR',
                                        );
                                      }
                                    },
                                    child: const Text('Update FW'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Progress Card
                ListenableBuilder(
                  listenable: _dfu.progress,
                  builder: (context, _) {
                    final fileSize = _dfu.progress.fileSize;
                    final completedSize = _dfu.progress.completedSize;
                    if (fileSize == null || completedSize == null) {
                      return const SizedBox();
                    }
                    final ratio = completedSize / fileSize;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update Progress: ${(ratio * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: ratio),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Right Side: DFU Console Logs
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppBar(
                    title: const Text(
                      'Console Logs',
                      style: TextStyle(fontSize: 14),
                    ),
                    backgroundColor: Colors.grey[900],
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        onPressed: () {
                          _dfu.setup.logs.clear();
                          _dfu.setup.notify();
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _dfu.setup,
                      builder: (context, _) {
                        final logs = _dfu.setup.logs;
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _scrollToBottom(),
                        );

                        return ListView.builder(
                          controller: _logScrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            Color levelColor = Colors.green;
                            if (log.level == 'ERROR') {
                              levelColor = Colors.red;
                            } else if (log.level == 'WARNING') {
                              levelColor = Colors.orange;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '[${log.formattedTimestamp}] ${log.level}: ${log.message}',
                                style: TextStyle(
                                  color: levelColor,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

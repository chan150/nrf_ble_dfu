import 'package:flutter/material.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNrfBleDfuForFlutter();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _showLogs = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _showLogs = !_showLogs),
        mini: true,
        child: Icon(_showLogs ? Icons.terminal_outlined : Icons.terminal),
      ),
      body: Row(
        children: [
          // Left: Controls
          Expanded(
            flex: 3,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                DfuFileSelect(),
                Divider(height: 32),
                BleEntrySetup(),
                Divider(height: 32),
                AutoBleDfu(),
                Divider(height: 32),
                BleConnectedDevice(),
                Divider(height: 32),
                DfuProgress(),
                Divider(height: 32),
                BleDeviceSelect(),
              ],
            ),
          ),
          if (_showLogs) ...[
            const VerticalDivider(width: 1),
            // Right: Logs
            const SizedBox(
              width: 350,
              child: LogConsole(),
            ),
          ],
        ],
      ),
    );
  }
}

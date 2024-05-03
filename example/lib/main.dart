import 'package:flutter/material.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NrfBleDfu().waitForCompletion();
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
  @override
  Widget build(BuildContext context) {
    const div = Divider(height: 0);
    const children = [
      DfuFileSelect(),
      BleEntrySetup(),
      AutoBleDfu(),
      BleConnectedDevice(),
      DfuProgress(),
      BleDeviceSelect(),
    ];
    return SafeArea(
      child: Scaffold(
        body: ListView.separated(
          itemCount: children.length,
          separatorBuilder: (_, __) => div,
          itemBuilder: (context, index) => children[index],
        ),
      ),
    );
  }
}

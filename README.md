## NRF BLE DFU
![Example](./fin.png)

The Nordic DFU over BLE library helps enable firmware updates of BLE-connected devices over Bluetooth Low Energy (BLE) in a universal way across different platforms like Windows, Android, iOS, Linux and macOS.

It provides an implementation of the Nordic DFU protocol which allows performing firmware updates and installing new firmware binaries on BLE peripherals compatible with this protocol. The library handles the low-level BLE communication and data transfer needed for the firmware update process.

Developers can use this library to add over-the-air firmware updating capabilities to their BLE applications and devices in a platform-independent manner. The same application code for initiating and performing a DFU process can work across multiple operating systems without changes.

This makes it very convenient for developers to roll out firmware updates to devices already in the field just by having them connect over BLE. End users also get an easy way to update devices without needing special tools or cables.

The Nordic DFU over BLE library abstracts away the differences in BLE implementations and provides a common API for firmware updates, enabling seamless development of DFU-capable products for all major platforms.

## Example
[example/lib/main.dart](example/lib/main.dart)
```dart
import 'package:flutter/cupertino.dart';
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
    return SafeArea(
      child: Scaffold(
        body: ListView(
          children: const [
            DfuFileSelect(),
            div,
            BleEntrySetup(),
            div,
            AutoBleDfu(),
            div,
            BleConnectedDevice(),
            DfuProgress(),
            div,
            BleDeviceSelect(),
          ],
        ),
      ),
    );
  }
}
```
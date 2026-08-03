import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';

class BleDeviceSelect extends StatefulWidget {
  const BleDeviceSelect({super.key});

  @override
  State<BleDeviceSelect> createState() => _BleDeviceSelectState();
}

class _BleDeviceSelectState extends State<BleDeviceSelect> {
  final TextEditingController _filterController = TextEditingController();
  String _filterText = "";
  bool _hideEmptyNames = true;

  @override
  void initState() {
    super.initState();
    FlutterBluePlus.startScan();
    _filterController.addListener(() {
      setState(() {
        _filterText = _filterController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _filterController.dispose();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Filter Bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filterController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Filter by name or MAC...',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () =>
                    setState(() => _hideEmptyNames = !_hideEmptyNames),
                icon: Icon(
                  _hideEmptyNames ? Icons.filter_list_off : Icons.filter_list,
                  color: _hideEmptyNames ? Colors.blue : Colors.grey,
                ),
                tooltip: _hideEmptyNames ? 'Show all' : 'Hide empty names',
              ),
            ],
          ),
        ),
        StreamBuilder<List<ScanResult>>(
          stream: FlutterBluePlus.scanResults,
          builder: (context, snapshot) {
            var list = snapshot.data ?? [];

            // Apply Filters
            list = list.where((item) {
              final name = item.device.platformName;
              final addr = item.device.remoteId.str;

              if (_hideEmptyNames && name.isEmpty) return false;

              if (_filterText.isNotEmpty) {
                return name.toLowerCase().contains(_filterText) ||
                    addr.toLowerCase().contains(_filterText);
              }

              return true;
            }).toList();

            // Sort by RSSI
            list.sort((a, b) => b.rssi.compareTo(a.rssi));

            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No devices found',
                    style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              shrinkWrap: true, // Crucial for being inside another ListView
              physics:
                  const NeverScrollableScrollPhysics(), // Let the outer ListView handle scrolling
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                final name = item.device.platformName;
                return ListTile(
                  dense: true,
                  leading: Text(
                    item.rssi.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: _rssiColor(item.rssi),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  title: Text(
                    name.isEmpty ? 'Unknown' : name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          name.isEmpty ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    item.device.remoteId.str,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TargetChecker(item: item),
                      CompleteChecker(item: item),
                      IconButton(
                        onPressed: () =>
                            item.device.connect(license: License.nonprofit),
                        tooltip: 'Connect',
                        icon: const Icon(Icons.bluetooth, size: 20),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Color _rssiColor(int rssi) {
    if (rssi > -60) return Colors.green;
    if (rssi > -80) return Colors.orange;
    return Colors.red;
  }
}

class TargetChecker extends StatelessWidget {
  const TargetChecker({super.key, required this.item});

  final ScanResult item;

  @override
  Widget build(BuildContext context) {
    final dfu = NrfBleDfu();
    return ListenableBuilder(
      listenable: dfu.setup,
      builder: (context, _) {
        final targets = dfu.setup.autoDfuTargets;
        final id = item.device.remoteId.str;
        final isTarget = targets.map((e) => e.remoteId.str).contains(id);

        return IconButton(
          onPressed: () {
            if (isTarget) {
              targets.removeWhere((e) => e.remoteId.str == id);
            } else {
              targets.add(item.device);
            }
            dfu.setup.notify();
          },
          icon: Icon(
            isTarget ? Icons.check_circle : Icons.add_circle_outline,
            size: 20,
            color: isTarget ? Colors.blue : Colors.grey,
          ),
        );
      },
    );
  }
}

class CompleteChecker extends StatelessWidget {
  const CompleteChecker({super.key, required this.item});

  final ScanResult item;

  @override
  Widget build(BuildContext context) {
    final dfu = NrfBleDfu();
    return ListenableBuilder(
      listenable: dfu.setup,
      builder: (context, _) {
        final completed = dfu.setup.autoDfuFinished;
        final id = item.device.remoteId.str;
        final isComplete = completed.map((e) => e.remoteId.str).contains(id);

        return IconButton(
          onPressed: () {
            if (isComplete) {
              completed.removeWhere((e) => e.remoteId.str == id);
            } else {
              completed.add(item.device);
            }
            dfu.setup.notify();
          },
          icon: Icon(
            isComplete ? Icons.playlist_add_check : Icons.playlist_add,
            size: 20,
            color: isComplete ? Colors.green : Colors.grey,
          ),
        );
      },
    );
  }
}

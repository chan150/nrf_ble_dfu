import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class AutoBleDfu extends StatelessObserverWidget {
  const AutoBleDfu({super.key});

  @override
  Widget build(BuildContext context) {
    final diff = NrfBleDfu()
        .setup
        .autoDfuTargets
        .difference(NrfBleDfu().setup.autoDfuFinished);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_fix_high, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Auto DFU Manager',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const Text('Auto Scan'),
              Observer(builder: (context) {
                return Switch(
                  value: NrfBleDfu().setup.isAutoScanEnabled,
                  onChanged: (value) => NrfBleDfu().toggleAutoScan(value),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: NrfBleDfu().autoDfu,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run Once'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: NrfBleDfu().refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const DfuHistoryDialog(),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('History'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (diff.isNotEmpty) ...[
            const Text('Waiting Queue:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                for (final item in diff)
                  Chip(
                    label: Text(
                      '${item.platformName} [${item.remoteId}]',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (NrfBleDfu().setup.autoDfuFinished.isNotEmpty) ...[
            const Text('Session Finished:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                for (final item in NrfBleDfu().setup.autoDfuFinished)
                  Chip(
                    label: Text(
                      '${item.platformName} [${item.remoteId}]',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

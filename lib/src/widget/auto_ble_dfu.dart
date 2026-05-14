import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';
import 'log_console.dart';

class AutoBleDfu extends StatelessObserverWidget {
  const AutoBleDfu({super.key});

  @override
  Widget build(BuildContext context) {
    final diff = NrfBleDfu()
        .setup
        .autoDfuTargets
        .difference(NrfBleDfu().setup.autoDfuFinished);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + toggles (compact)
          Row(
            children: [
              const Icon(Icons.auto_fix_high, color: Colors.blue, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Auto DFU',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const Text('Scan', style: TextStyle(fontSize: 12)),
              Observer(builder: (context) {
                return Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: NrfBleDfu().setup.isAutoScanEnabled,
                    onChanged: (value) => NrfBleDfu().toggleAutoScan(value),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }),
              const SizedBox(width: 4),
              const Text('Update', style: TextStyle(fontSize: 12)),
              Observer(builder: (context) {
                return Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: NrfBleDfu().setup.isAutoUpdateEnabled,
                    onChanged: (value) => NrfBleDfu().toggleAutoUpdate(value),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 6),
          // Action buttons (icon-only, compact)
          Row(
            children: [
              _CompactButton(
                icon: Icons.play_arrow,
                label: 'Run Once',
                color: Colors.blue,
                onPressed: NrfBleDfu().autoDfu,
              ),
              const SizedBox(width: 8),
              _CompactButton(
                icon: Icons.refresh,
                label: 'Refresh',
                onPressed: NrfBleDfu().refresh,
              ),
              const SizedBox(width: 8),
              _CompactButton(
                icon: Icons.history,
                label: 'History',
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => const DfuHistoryDialog(),
                ),
              ),
            ],
          ),
          // Waiting queue (collapsible style)
          if (diff.isNotEmpty) ...[
            const SizedBox(height: 6),
            _StatusChips(
              label: 'Queue',
              items: diff.map((e) => e.platformName).toList(),
              color: Colors.orange,
            ),
          ],
          if (NrfBleDfu().setup.autoDfuFinished.isNotEmpty) ...[
            const SizedBox(height: 4),
            _StatusChips(
              label: 'Done',
              items: NrfBleDfu().setup.autoDfuFinished.map((e) => e.platformName).toList(),
              color: Colors.green,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactButton extends StatelessWidget {
  const _CompactButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isFilled = color != null;
    return SizedBox(
      height: 32,
      child: isFilled
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 14),
              label: Text(label, style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 14),
              label: Text(label, style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({
    required this.label,
    required this.items,
    required this.color,
  });

  final String label;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 2,
            children: items
                .map((name) => Chip(
                      label: Text(name, style: const TextStyle(fontSize: 10)),
                      backgroundColor: color.withOpacity(0.08),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

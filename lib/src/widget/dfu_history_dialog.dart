import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';
import 'package:intl/intl.dart';

class DfuHistoryDialog extends StatelessWidget {
  const DfuHistoryDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 600,
        height: 800,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Update History',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Observer(
                builder: (context) {
                  final history = NrfBleDfu().setup.history;
                  if (history.isEmpty) {
                    return const Center(child: Text('No history found.'));
                  }
                  return ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final entry = history[index];
                      final isSuccess = entry.status == 'success';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSuccess
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          child: Icon(
                            isSuccess ? Icons.check : Icons.error,
                            color: isSuccess ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(entry.deviceName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.remoteId),
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm:ss')
                                  .format(entry.timestamp),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                            if (entry.note != null)
                              Text(
                                entry.note!,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.red),
                              ),
                          ],
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            NrfBleDfu().retryDfu(entry.remoteId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${entry.deviceName} added back to queue.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text('Re-update'),
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
    );
  }
}

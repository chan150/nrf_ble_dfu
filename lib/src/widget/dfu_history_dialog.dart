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
                TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear History'),
                        content: const Text('Are you sure you want to delete all history?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await NrfBleDfu().clearHistory();
                    }
                  },
                  icon: const Icon(Icons.delete_forever, size: 18, color: Colors.redAccent),
                  label: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DefaultTabController(
              length: 2,
              child: Expanded(
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Success'),
                        Tab(text: 'Failed'),
                      ],
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blue,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _HistoryList(isSuccessView: true),
                          _HistoryList(isSuccessView: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.isSuccessView});

  final bool isSuccessView;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final history = isSuccessView
            ? NrfBleDfu().setup.successHistory
            : NrfBleDfu().setup.failureHistory;

        if (history.isEmpty) {
          return Center(
            child: Text(
              isSuccessView ? 'No successful updates yet.' : 'No failed updates.',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          itemCount: history.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = history[index];
            final isSuccess = entry.status == 'success';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isSuccess
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                child: Icon(
                  isSuccess ? Icons.check : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              title: Text(
                entry.deviceName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.remoteId, style: const TextStyle(fontSize: 12)),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.timestamp),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  if (entry.note != null && entry.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        entry.note!,
                        style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
              trailing: isSuccess
                  ? null
                  : TextButton(
                      onPressed: () {
                        NrfBleDfu().retryDfu(entry.remoteId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${entry.deviceName} will be retried.'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Text('Retry Now'),
                    ),
            );
          },
        );
      },
    );
  }
}

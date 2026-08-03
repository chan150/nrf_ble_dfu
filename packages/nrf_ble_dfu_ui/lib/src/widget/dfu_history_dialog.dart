import 'package:flutter/material.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';
import 'package:intl/intl.dart';

class DfuHistoryDialog extends StatefulWidget {
  const DfuHistoryDialog({super.key});

  @override
  State<DfuHistoryDialog> createState() => _DfuHistoryDialogState();
}

class _DfuHistoryDialogState extends State<DfuHistoryDialog> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
                        content: const Text(
                            'Are you sure you want to delete all history?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Clear',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await NrfBleDfu().clearHistory();
                    }
                  },
                  icon: const Icon(Icons.delete_forever,
                      size: 18, color: Colors.redAccent),
                  label: const Text('Clear All',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by device name, MAC, SN, or firmware...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 15),
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
                          _HistoryList(
                              isSuccessView: true, searchQuery: _searchQuery),
                          _HistoryList(
                              isSuccessView: false, searchQuery: _searchQuery),
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
  const _HistoryList({required this.isSuccessView, required this.searchQuery});

  final bool isSuccessView;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final dfu = NrfBleDfu();
    return ListenableBuilder(
      listenable: dfu.setup,
      builder: (context, _) {
        final history =
            isSuccessView ? dfu.setup.successHistory : dfu.setup.failureHistory;

        // Apply search filter
        final filteredHistory = history.where((entry) {
          if (searchQuery.isEmpty) return true;
          final query = searchQuery.toLowerCase();
          return entry.deviceName.toLowerCase().contains(query) ||
              entry.remoteId.toLowerCase().contains(query) ||
              entry.serialNumber.toLowerCase().contains(query) ||
              entry.firmwareName.toLowerCase().contains(query) ||
              (entry.note?.toLowerCase().contains(query) ?? false);
        }).toList();

        if (filteredHistory.isEmpty) {
          return Center(
            child: Text(
              searchQuery.isEmpty
                  ? (isSuccessView
                      ? 'No successful updates yet.'
                      : 'No failed updates.')
                  : 'No matching records found.',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        final items = <dynamic>[];
        DateTime? lastTime;
        for (final entry in filteredHistory) {
          if (lastTime == null ||
              lastTime.difference(entry.timestamp).inMinutes.abs() > 10) {
            items.add(entry.timestamp);
          }
          items.add(entry);
          lastTime = entry.timestamp;
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];

            if (item is DateTime) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 14, color: Colors.blueGrey[300]),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MM-dd HH:mm').format(item),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Divider()),
                  ],
                ),
              );
            }

            final entry = item as DfuHistoryEntry;
            final isSuccess = entry.status == 'success';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isSuccess
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                child: Icon(
                  isSuccess ? Icons.check : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              title: Text(
                entry.deviceName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'MAC: ${entry.remoteId} | SN: ${entry.serialNumber.isNotEmpty ? entry.serialNumber : "N/A"}',
                      style: const TextStyle(fontSize: 12)),
                  if (entry.firmwareName.isNotEmpty)
                    Text('Firmware: ${entry.firmwareName}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500)),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.timestamp),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  if (entry.note != null && entry.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        entry.note!,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isSuccess)
                    TextButton(
                      onPressed: () {
                        dfu.retryDfu(entry.remoteId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('${entry.deviceName} will be retried.'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Text('Retry Now'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.grey, size: 20),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Record'),
                          content: const Text(
                              'Are you sure you want to delete this history record?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        dfu.deleteHistoryEntry(entry);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

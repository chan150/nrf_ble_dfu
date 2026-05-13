import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../nrf_ble_dfu.dart';


class LogConsole extends StatefulWidget {
  final double width;
  const LogConsole({super.key, this.width = 300});

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dfu = NrfBleDfu();

    return Container(
      width: widget.width,
      color: Colors.grey[900],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.black45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LOG CONSOLE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.white54, size: 18),
                  onPressed: () {
                    dfu.setup.logs.clear();
                    // Optional: clear from DB too? 
                    // DfuDatabase().clearLogs();
                  },
                  tooltip: 'Clear view',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          Expanded(
            child: Observer(
              builder: (context) {
                final logs = dfu.setup.logs;
                
                // Auto scroll on new logs
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: SelectableText.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '[${log.formattedTimestamp}] ',
                              style: const TextStyle(color: Colors.blueGrey, fontSize: 11, fontFamily: 'monospace'),
                            ),
                            TextSpan(
                              text: '${log.level}: ',
                              style: TextStyle(
                                color: _getLevelColor(log.level),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                            TextSpan(
                              text: log.message,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                            ),
                          ],
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
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'ERROR': return Colors.redAccent;
      case 'WARNING': return Colors.orangeAccent;
      case 'DEBUG': return Colors.blueAccent;
      default: return Colors.greenAccent;
    }
  }
}

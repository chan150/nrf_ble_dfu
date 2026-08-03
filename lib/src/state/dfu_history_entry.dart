class DfuHistoryEntry {
  final String remoteId;
  final String deviceName;
  final DateTime timestamp;
  final String status; // 'success', 'failed', 'started'
  final String? note;
  final String firmwareName;
  final String serialNumber;

  DfuHistoryEntry({
    required this.remoteId,
    required this.deviceName,
    required this.timestamp,
    required this.status,
    required this.firmwareName,
    required this.serialNumber,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'remote_id': remoteId,
        'device_name': deviceName,
        'timestamp': timestamp.toIso8601String(),
        'status': status,
        'note': note,
        'firmware_name': firmwareName,
        'serial_number': serialNumber,
      };

  factory DfuHistoryEntry.fromJson(Map<String, dynamic> json) =>
      DfuHistoryEntry(
        remoteId: json['remote_id'] as String? ?? '',
        deviceName: json['device_name'] as String? ?? '',
        timestamp: DateTime.parse(
            json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
        status: json['status'] as String? ?? 'unknown',
        note: json['note'] as String?,
        firmwareName: json['firmware_name'] as String? ?? '',
        serialNumber: json['serial_number'] as String? ?? '',
      );
}

class DfuHistoryContainer {
  final List<DfuHistoryEntry> history;

  DfuHistoryContainer({required this.history});

  Map<String, dynamic> toJson() => {
        'history': history.map((e) => e.toJson()).toList(),
      };

  factory DfuHistoryContainer.fromJson(Map<String, dynamic> json) {
    return DfuHistoryContainer(
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => DfuHistoryEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

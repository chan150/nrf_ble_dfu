import 'package:intl/intl.dart';

class LogEntry {
  final int? id;
  final DateTime timestamp;
  final String level;
  final String message;

  LogEntry({
    this.id,
    required this.timestamp,
    required this.level,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'level': level,
      'message': message,
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      level: map['level'],
      message: map['message'],
    );
  }

  String get formattedTimestamp => DateFormat('HH:mm:ss.SSS').format(timestamp);
}

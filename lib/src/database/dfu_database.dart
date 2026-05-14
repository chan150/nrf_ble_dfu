import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../state/dfu_history_entry.dart';
import '../nrf_ble_dfu.dart';
import '../database/log_entry.dart';

class DfuDatabase {
  static final DfuDatabase _instance = DfuDatabase._internal();
  factory DfuDatabase() => _instance;
  DfuDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    if (_db == null) throw Exception('Failed to initialize database');
    return _db!;
  }

  Future<Database> _initDb() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    try {
      dbPath = await getDatabasesPath();
    } catch (e) {
      // Fallback for environments where getDatabasesPath() might fail
      final directory = await getApplicationDocumentsDirectory();
      dbPath = directory.path;
    }
    final path = join(dbPath, 'nrf_ble_dfu.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            remoteId TEXT,
            deviceName TEXT,
            status TEXT,
            timestamp TEXT,
            note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            level TEXT,
            message TEXT
          )
        ''');
      },
    );
  }

  // History operations
  Future<void> insertHistory(DfuHistoryEntry entry) async {
    final db = await database;
    await db.insert('history', {
      'remoteId': entry.remoteId,
      'deviceName': entry.deviceName,
      'status': entry.status,
      'timestamp': entry.timestamp.toIso8601String(),
      'note': entry.note,
    });
  }

  Future<List<DfuHistoryEntry>> getHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('history', orderBy: 'timestamp DESC');
    return maps
        .map((m) => DfuHistoryEntry(
              remoteId: m['remoteId'],
              deviceName: m['deviceName'],
              status: m['status'],
              timestamp: DateTime.parse(m['timestamp']),
              note: m['note'],
            ))
        .toList();
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('history');
  }

  // Log operations
  Future<void> insertLog(LogEntry entry) async {
    final db = await database;
    await db.insert('logs', entry.toMap());
  }

  Future<List<LogEntry>> getLogs({int limit = 100}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('logs', orderBy: 'timestamp DESC', limit: limit);
    return maps.map((m) => LogEntry.fromMap(m)).toList();
  }

  Future<void> clearLogs() async {
    final db = await database;
    await db.delete('logs');
  }
}

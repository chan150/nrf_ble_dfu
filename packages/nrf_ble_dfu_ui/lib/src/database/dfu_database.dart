import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class SqfliteDfuDatabase {
  static final SqfliteDfuDatabase _instance = SqfliteDfuDatabase._internal();
  factory SqfliteDfuDatabase() => _instance;
  SqfliteDfuDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    if (_db == null) throw Exception('Failed to initialize database');
    return _db!;
  }

  Future<void> initialize() async {
    await database;
  }

  Future<Database> _initDb() async {
    final ffi = Platform.isWindows || Platform.isLinux;
    if (ffi) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    try {
      // Under the ffi factory getDatabasesPath() answers with a path relative
      // to the working directory, so the database follows whatever launched
      // the app instead of staying with it: run from a shell it lands in the
      // project, run from a shortcut it lands beside the executable, and an
      // installed build cannot write there at all. It does not throw, so the
      // fallback below never covered this. Mobile is unaffected, where the
      // platform answers with its own per-app directory.
      dbPath = ffi
          ? (await getApplicationSupportDirectory()).path
          : await getDatabasesPath();
    } catch (e) {
      // Fallback for environments where neither is available.
      final directory = await getApplicationDocumentsDirectory();
      dbPath = directory.path;
    }
    final path = join(dbPath, 'nrf_ble_dfu.db');

    return await openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS history');
          await db.execute('DROP TABLE IF EXISTS logs');
          await db.execute('''
            CREATE TABLE history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              remoteId TEXT,
              deviceName TEXT,
              status TEXT,
              timestamp TEXT,
              note TEXT,
              firmwareName TEXT,
              serialNumber TEXT
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
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            remoteId TEXT,
            deviceName TEXT,
            status TEXT,
            timestamp TEXT,
            note TEXT,
            firmwareName TEXT,
            serialNumber TEXT
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

  Future<void> insertHistory(DfuHistoryEntry entry) async {
    final db = await database;
    await db.insert('history', {
      'remoteId': entry.remoteId,
      'deviceName': entry.deviceName,
      'status': entry.status,
      'timestamp': entry.timestamp.toIso8601String(),
      'note': entry.note,
      'firmwareName': entry.firmwareName,
      'serialNumber': entry.serialNumber,
    });
  }

  Future<List<DfuHistoryEntry>> getHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('history', orderBy: 'timestamp DESC');
    return maps
        .map((m) => DfuHistoryEntry(
              remoteId: m['remoteId'] ?? '',
              deviceName: m['deviceName'] ?? '',
              status: m['status'] ?? '',
              timestamp: DateTime.parse(m['timestamp']),
              note: m['note'],
              firmwareName: m['firmwareName'] ?? '',
              serialNumber: m['serialNumber'] ?? '',
            ))
        .toList();
  }

  Future<void> deleteHistoryEntry(String remoteId, String timestampIso) async {
    final db = await database;
    await db.delete(
      'history',
      where: 'remoteId = ? AND timestamp = ?',
      whereArgs: [remoteId, timestampIso],
    );
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('history');
  }

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

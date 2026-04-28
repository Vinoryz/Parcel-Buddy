import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = 'parcelbuddy.db';
  static const _databaseVersion = 1;

  static const table = 'user_history';
  static const colId = 'id';
  static const colResi = 'resi_number';
  static const colAction = 'action_type';
  static const colNotes = 'user_notes';
  static const colDate = 'recorded_at';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    return openDatabase(path, version: _databaseVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colResi TEXT NOT NULL,
        $colAction TEXT NOT NULL,
        $colNotes TEXT,
        $colDate TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertLog(Map<String, dynamic> row) async {
    final db = await database;
    return db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAllLogs() async {
    final db = await database;
    return db.query(table, orderBy: '$colDate DESC');
  }

  Future<int> updateNote(int id, String note) async {
    final db = await database;
    return db.update(table, {colNotes: note}, where: '$colId = ?', whereArgs: [id]);
  }

  Future<int> deleteLog(int id) async {
    final db = await database;
    return db.delete(table, where: '$colId = ?', whereArgs: [id]);
  }
}

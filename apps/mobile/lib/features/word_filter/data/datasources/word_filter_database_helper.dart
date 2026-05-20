import 'package:sqflite/sqflite.dart';

class WordFilterDatabaseHelper {
  static const _dbName = 'word_filter.db';
  static const _dbVersion = 1;
  static const _table = 'banned_words';

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _openDb();
  }

  Future<Database> _openDb() =>
      openDatabase(_dbName, version: _dbVersion, onCreate: _onCreate);

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        language TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_language ON $_table(language)');
  }

  Future<void> insertWordsBatch(List<Map<String, String>> words) async {
    final db = await database;
    final batch = db.batch();
    for (final w in words) {
      batch.insert(_table, w, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getWordsByLanguage(String language) async {
    final db = await database;
    return db.query(_table, where: 'language = ?', whereArgs: [language]);
  }
}

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite local (Android/iOS) con tablas separadas por `user_id`.
///
/// La caché de libros y de búsquedas es información pública; historial,
/// favoritos y biblioteca son personales y siempre se consultan filtrando por
/// el `user_id` de la sesión activa.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  DatabaseFactory? _factoryOverride;
  String? _pathOverride;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final factory = _factoryOverride ?? databaseFactory;
    final path = _pathOverride ??
        p.join(await getDatabasesPath(), 'biblioteca_practica5.db');
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
      ),
    );
  }

  /// Sólo para pruebas unitarias (sqflite_common_ffi).
  void configureForTests({
    required DatabaseFactory factory,
    required String path,
  }) {
    _factoryOverride = factory;
    _pathOverride = path;
    _db = null;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE books (
        ol_key TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT,
        cover_id INTEGER,
        subjects TEXT NOT NULL DEFAULT '',
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE search_cache (
        user_id INTEGER NOT NULL,
        query_key TEXT NOT NULL,
        page INTEGER NOT NULL DEFAULT 1,
        payload TEXT NOT NULL,
        fetched_at TEXT NOT NULL,
        PRIMARY KEY (user_id, query_key, page)
      )
    ''');

    batch.execute('''
      CREATE TABLE search_history (
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        query TEXT NOT NULL,
        created_at TEXT NOT NULL,
        op_id TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_history_user ON search_history(user_id, created_at DESC)',
    );

    batch.execute('''
      CREATE TABLE favorites (
        user_id INTEGER NOT NULL,
        ol_key TEXT NOT NULL,
        title TEXT NOT NULL,
        author TEXT,
        cover_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        dirty INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, ol_key)
      )
    ''');

    batch.execute('''
      CREATE TABLE library_items (
        public_id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        ol_key TEXT NOT NULL,
        title TEXT NOT NULL,
        author TEXT,
        cover_id INTEGER,
        status TEXT NOT NULL DEFAULT 'want_to_read',
        rating INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        dirty INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_library_user ON library_items(user_id, updated_at DESC)',
    );

    batch.execute('''
      CREATE TABLE pending_ops (
        op_id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_pending_user ON pending_ops(user_id, created_at)',
    );

    batch.execute('''
      CREATE TABLE recommendations (
        user_id INTEGER PRIMARY KEY,
        generated_at TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE sync_state (
        user_id INTEGER PRIMARY KEY,
        last_sync_at TEXT,
        last_error TEXT,
        status TEXT NOT NULL DEFAULT 'idle'
      )
    ''');

    await batch.commit(noResult: true);
  }

  Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert('meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

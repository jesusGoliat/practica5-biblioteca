import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/db/app_database.dart';
import '../core/models/book.dart';
import '../core/models/favorite_book.dart';
import '../core/models/history_entry.dart';
import '../core/models/library_item.dart';
import '../core/models/recommendation.dart';
import '../core/network/api_exception.dart';
import '../core/network/backend_api.dart';
import '../core/network/open_library_api.dart';

class SearchOutcome {
  const SearchOutcome({
    required this.books,
    required this.total,
    required this.fromCache,
    required this.fetchedAt,
    this.elapsed,
    this.error,
  });

  final List<Book> books;
  final int total;
  final bool fromCache;
  final DateTime fetchedAt;
  final Duration? elapsed;
  final ApiException? error;
}

class SyncStatus {
  const SyncStatus({
    this.pending = 0,
    this.lastSyncAt,
    this.lastError,
    this.syncing = false,
  });

  final int pending;
  final DateTime? lastSyncAt;
  final String? lastError;
  final bool syncing;
}

class RecommendationSet {
  const RecommendationSet({
    required this.items,
    required this.generatedAt,
    required this.criterion,
    this.fromCache = false,
  });

  final List<Recommendation> items;
  final DateTime generatedAt;
  final String criterion;
  final bool fromCache;
}

/// Repositorio local-first: toda lectura/escritura pasa por SQLite filtrando
/// por `user_id`; los cambios se encolan en `pending_ops` y se envían con
/// `/sync` (idempotente por `op_id`). Estrategia de conflictos: primero se
/// envían (push) las operaciones locales y después se descargan (pull) los
/// datos del servidor; una fila local con cambios pendientes (`dirty = 1`)
/// nunca se sobrescribe, el resto adopta la versión del servidor.
class Repository {
  Repository({
    AppDatabase? db,
    required this.api,
    required this.openLibrary,
    Uuid? uuid,
  })  : _db = db ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final BackendApi api;
  final OpenLibraryApi openLibrary;
  final Uuid _uuid;

  int? userId;
  bool _syncing = false;

  int get _uid {
    final id = userId;
    if (id == null) throw StateError('No hay sesión activa.');
    return id;
  }

  Future<Database> get _database => _db.database;

  String _now() => DateTime.now().toUtc().toIso8601String();

  // --- Búsqueda con caché ---------------------------------------------------
  Future<SearchOutcome> search(String query, {int page = 1}) async {
    final q = query.trim();
    final key = q.toLowerCase();
    SearchOutcome outcome;
    try {
      final result = await openLibrary.search(q, page: page);
      final now = DateTime.now();
      await _cacheSearch(key, page, result.books, result.total, now);
      await saveBooks(result.books);
      outcome = SearchOutcome(
        books: result.books,
        total: result.total,
        fromCache: false,
        fetchedAt: now,
        elapsed: result.elapsed,
      );
    } on ApiException catch (error) {
      final cached = await _readSearchCache(key, page, error);
      if (cached == null) {
        await addHistory(q);
        rethrow;
      }
      outcome = cached;
    }
    await addHistory(q);
    return outcome;
  }

  Future<void> _cacheSearch(
    String key,
    int page,
    List<Book> books,
    int total,
    DateTime at,
  ) async {
    final db = await _database;
    await db.insert(
      'search_cache',
      {
        'user_id': _uid,
        'query_key': key,
        'page': page,
        'payload': jsonEncode({
          'total': total,
          'books': books.map((b) => b.toJson()).toList(),
        }),
        'fetched_at': at.toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SearchOutcome?> _readSearchCache(
    String key,
    int page,
    ApiException error,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'search_cache',
      where: 'user_id = ? AND query_key = ? AND page = ?',
      whereArgs: [_uid, key, page],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final data = jsonDecode(rows.first['payload'] as String) as Map;
      final books = (data['books'] as List)
          .map((b) => Book.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList();
      return SearchOutcome(
        books: books,
        total: (data['total'] as num?)?.toInt() ?? books.length,
        fromCache: true,
        fetchedAt: DateTime.parse(rows.first['fetched_at'] as String).toLocal(),
        error: error,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBooks(List<Book> books) async {
    final db = await _database;
    final batch = db.batch();
    for (final book in books) {
      if (book.olKey.isEmpty) continue;
      batch.insert(
        'books',
        {
          'ol_key': book.olKey,
          'title': book.title,
          'author': book.author,
          'cover_id': book.coverId,
          'subjects': book.subjects.take(12).join('|'),
          'payload': jsonEncode(book.toJson()),
          'updated_at': _now(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Book?> cachedBook(String olKey) async {
    final db = await _database;
    final rows = await db.query(
      'books',
      where: 'ol_key = ?',
      whereArgs: [olKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return Book.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(rows.first['payload'] as String) as Map,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // --- Historial ------------------------------------------------------------
  Future<void> addHistory(String query) async {
    final db = await _database;
    final last = await db.query(
      'search_history',
      where: 'user_id = ?',
      whereArgs: [_uid],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (last.isNotEmpty && last.first['query'] == query) return;
    final id = _uuid.v4();
    final opId = _uuid.v4();
    final createdAt = _now();
    await db.insert('search_history', {
      'id': id,
      'user_id': _uid,
      'query': query,
      'created_at': createdAt,
      'op_id': opId,
      'synced': 0,
    });
    await _enqueue('history_add', {
      'id': id,
      'op_id': opId,
      'query': query,
      'created_at': createdAt,
    }, opId: opId);
  }

  Future<List<HistoryEntry>> history() async {
    final db = await _database;
    final rows = await db.query(
      'search_history',
      where: 'user_id = ?',
      whereArgs: [_uid],
      orderBy: 'created_at DESC',
      limit: 100,
    );
    return rows
        .map(
          (r) => HistoryEntry(
            id: r['id'] as String,
            query: r['query'] as String,
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          ),
        )
        .toList();
  }

  Future<void> clearHistory() async {
    final db = await _database;
    await db.delete('search_history', where: 'user_id = ?', whereArgs: [_uid]);
    await db.delete(
      'pending_ops',
      where: "user_id = ? AND type = 'history_add'",
      whereArgs: [_uid],
    );
    try {
      await api.clearHistory();
    } on ApiException {
      // Sin red: el servidor conservará el historial anterior hasta limpiar de nuevo.
    }
  }

  // --- Favoritos ------------------------------------------------------------
  Future<List<FavoriteBook>> favorites() async {
    final db = await _database;
    final rows = await db.query(
      'favorites',
      where: 'user_id = ? AND deleted = 0',
      whereArgs: [_uid],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_favoriteFromRow).toList();
  }

  FavoriteBook _favoriteFromRow(Map<String, Object?> r) => FavoriteBook(
        olKey: r['ol_key'] as String,
        title: r['title'] as String,
        author: r['author'] as String?,
        coverId: r['cover_id'] as int?,
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: DateTime.parse(r['updated_at'] as String),
        deleted: (r['deleted'] as int) == 1,
      );

  Future<void> setFavorite(Book book, bool favorite) async {
    final db = await _database;
    final now = _now();
    final existing = await db.query(
      'favorites',
      where: 'user_id = ? AND ol_key = ?',
      whereArgs: [_uid, book.olKey],
      limit: 1,
    );
    await db.insert(
      'favorites',
      {
        'user_id': _uid,
        'ol_key': book.olKey,
        'title': book.title,
        'author': book.author,
        'cover_id': book.coverId,
        'created_at':
            existing.isEmpty ? now : existing.first['created_at'] as String,
        'updated_at': now,
        'dirty': 1,
        'deleted': favorite ? 0 : 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await saveBooks([book]);
    await _enqueue('favorite_set', {
      'ol_key': book.olKey,
      'title': book.title,
      'author': book.author,
      'cover_id': book.coverId,
      'favorite': favorite,
    });
  }

  // --- Biblioteca -----------------------------------------------------------
  Future<List<LibraryItem>> library() async {
    final db = await _database;
    final rows = await db.query(
      'library_items',
      where: 'user_id = ? AND deleted = 0',
      whereArgs: [_uid],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_libraryFromRow).toList();
  }

  LibraryItem _libraryFromRow(Map<String, Object?> r) => LibraryItem(
        publicId: r['public_id'] as String,
        olKey: r['ol_key'] as String,
        title: r['title'] as String,
        author: r['author'] as String?,
        coverId: r['cover_id'] as int?,
        status: r['status'] as String,
        rating: r['rating'] as int?,
        notes: r['notes'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: DateTime.parse(r['updated_at'] as String),
        deleted: (r['deleted'] as int) == 1,
      );

  Future<LibraryItem> addToLibrary(Book book, String status) async {
    final db = await _database;
    final existing = await db.query(
      'library_items',
      where: 'user_id = ? AND ol_key = ?',
      whereArgs: [_uid, book.olKey],
      limit: 1,
    );
    final now = _now();
    final publicId = existing.isEmpty
        ? _uuid.v4()
        : existing.first['public_id'] as String;
    final item = LibraryItem(
      publicId: publicId,
      olKey: book.olKey,
      title: book.title,
      author: book.author,
      coverId: book.coverId,
      status: status,
      rating: existing.isEmpty ? null : existing.first['rating'] as int?,
      notes: existing.isEmpty ? null : existing.first['notes'] as String?,
      createdAt: existing.isEmpty
          ? DateTime.parse(now)
          : DateTime.parse(existing.first['created_at'] as String),
      updatedAt: DateTime.parse(now),
    );
    await _writeLibrary(item);
    await saveBooks([book]);
    return item;
  }

  Future<void> updateLibraryItem(
    LibraryItem item, {
    String? status,
    int? rating,
    String? notes,
  }) async {
    final updated = item.copyWith(
      status: status,
      rating: rating,
      notes: notes,
      updatedAt: DateTime.now().toUtc(),
    );
    await _writeLibrary(updated);
  }

  Future<void> _writeLibrary(LibraryItem item) async {
    final db = await _database;
    await db.insert(
      'library_items',
      {
        'public_id': item.publicId,
        'user_id': _uid,
        'ol_key': item.olKey,
        'title': item.title,
        'author': item.author,
        'cover_id': item.coverId,
        'status': item.status,
        'rating': item.rating,
        'notes': item.notes,
        'created_at': item.createdAt.toUtc().toIso8601String(),
        'updated_at': item.updatedAt.toUtc().toIso8601String(),
        'dirty': 1,
        'deleted': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _enqueue('library_upsert', {
      'public_id': item.publicId,
      'ol_key': item.olKey,
      'title': item.title,
      'author': item.author,
      'cover_id': item.coverId,
      'status': item.status,
      'rating': item.rating,
      'notes': item.notes,
      'deleted': false,
    });
  }

  Future<void> deleteLibraryItem(LibraryItem item) async {
    final db = await _database;
    await db.update(
      'library_items',
      {'deleted': 1, 'dirty': 1, 'updated_at': _now()},
      where: 'public_id = ? AND user_id = ?',
      whereArgs: [item.publicId, _uid],
    );
    await _enqueue('library_delete', {'public_id': item.publicId});
  }

  // --- Cola de operaciones y sincronización ---------------------------------
  Future<void> _enqueue(
    String type,
    Map<String, dynamic> data, {
    String? opId,
  }) async {
    final db = await _database;
    await db.insert('pending_ops', {
      'op_id': opId ?? _uuid.v4(),
      'user_id': _uid,
      'type': type,
      'payload': jsonEncode(data),
      'created_at': _now(),
      'attempts': 0,
    });
  }

  Future<SyncStatus> syncStatus() async {
    final db = await _database;
    final pending = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM pending_ops WHERE user_id = ?',
            [_uid],
          ),
        ) ??
        0;
    final rows = await db.query(
      'sync_state',
      where: 'user_id = ?',
      whereArgs: [_uid],
      limit: 1,
    );
    DateTime? last;
    String? error;
    if (rows.isNotEmpty) {
      final raw = rows.first['last_sync_at'] as String?;
      last = raw == null ? null : DateTime.parse(raw).toLocal();
      error = rows.first['last_error'] as String?;
    }
    return SyncStatus(
      pending: pending,
      lastSyncAt: last,
      lastError: error,
      syncing: _syncing,
    );
  }

  Future<void> _setSyncState({String? lastSyncAt, String? error}) async {
    final db = await _database;
    final rows = await db.query(
      'sync_state',
      where: 'user_id = ?',
      whereArgs: [_uid],
      limit: 1,
    );
    await db.insert(
      'sync_state',
      {
        'user_id': _uid,
        'last_sync_at': lastSyncAt ??
            (rows.isEmpty ? null : rows.first['last_sync_at'] as String?),
        'last_error': error,
        'status': error == null ? 'idle' : 'error',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Envía la cola (push) y descarga el estado del servidor (pull).
  /// Devuelve `true` si todo terminó sin error.
  Future<bool> sync() async {
    if (_syncing) return true;
    _syncing = true;
    try {
      final db = await _database;
      final rows = await db.query(
        'pending_ops',
        where: 'user_id = ?',
        whereArgs: [_uid],
        orderBy: 'created_at ASC',
        limit: 200,
      );
      if (rows.isNotEmpty) {
        final ops = rows
            .map(
              (r) => {
                'op_id': r['op_id'],
                'type': r['type'],
                'data': jsonDecode(r['payload'] as String),
              },
            )
            .toList();
        final response = await api.sync(ops);
        final results = (response['results'] as List?) ?? const [];
        for (final raw in results.whereType<Map>()) {
          final opId = raw['op_id'] as String;
          final status = raw['status'] as String;
          final row = rows.firstWhere(
            (r) => r['op_id'] == opId,
            orElse: () => const {},
          );
          if (row.isEmpty) continue;
          if (status == 'applied' || status == 'duplicate') {
            await _markApplied(row);
            await db.delete(
              'pending_ops',
              where: 'op_id = ?',
              whereArgs: [opId],
            );
          } else {
            await db.update(
              'pending_ops',
              {
                'attempts': (row['attempts'] as int) + 1,
                'last_error': raw['detail'] as String?,
              },
              where: 'op_id = ?',
              whereArgs: [opId],
            );
          }
        }
      }
      await _pull();
      await _setSyncState(lastSyncAt: _now());
      return true;
    } on ApiException catch (error) {
      await _setSyncState(error: error.message);
      return false;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _markApplied(Map<String, Object?> op) async {
    final db = await _database;
    final data = jsonDecode(op['payload'] as String) as Map<String, dynamic>;
    switch (op['type']) {
      case 'history_add':
        await db.update(
          'search_history',
          {'synced': 1},
          where: 'id = ? AND user_id = ?',
          whereArgs: [data['id'], _uid],
        );
      case 'favorite_set':
        if (!await _hasPending('favorite_set', 'ol_key', data['ol_key'])) {
          await db.update(
            'favorites',
            {'dirty': 0},
            where: 'user_id = ? AND ol_key = ?',
            whereArgs: [_uid, data['ol_key']],
          );
        }
      case 'library_upsert' || 'library_delete':
        if (!await _hasPending(
          op['type'] as String,
          'public_id',
          data['public_id'],
          excluding: op['op_id'] as String,
        )) {
          await db.update(
            'library_items',
            {'dirty': 0},
            where: 'public_id = ? AND user_id = ?',
            whereArgs: [data['public_id'], _uid],
          );
        }
    }
  }

  Future<bool> _hasPending(
    String type,
    String field,
    Object? value, {
    String? excluding,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'pending_ops',
      where: 'user_id = ? AND type LIKE ?',
      whereArgs: [_uid, type.startsWith('library') ? 'library_%' : type],
    );
    for (final row in rows) {
      if (row['op_id'] == excluding) continue;
      final data = jsonDecode(row['payload'] as String) as Map;
      if (data[field] == value) return true;
    }
    return false;
  }

  Future<void> _pull() async {
    final db = await _database;

    final library = await api.library(includeDeleted: true);
    for (final item in library) {
      final local = await db.query(
        'library_items',
        where: 'public_id = ? AND user_id = ?',
        whereArgs: [item.publicId, _uid],
        limit: 1,
      );
      if (local.isNotEmpty && local.first['dirty'] == 1) continue;
      await db.delete(
        'library_items',
        where: 'user_id = ? AND ol_key = ? AND public_id != ? AND dirty = 0',
        whereArgs: [_uid, item.olKey, item.publicId],
      );
      await db.insert(
        'library_items',
        {
          'public_id': item.publicId,
          'user_id': _uid,
          'ol_key': item.olKey,
          'title': item.title,
          'author': item.author,
          'cover_id': item.coverId,
          'status': item.status,
          'rating': item.rating,
          'notes': item.notes,
          'created_at': item.createdAt.toUtc().toIso8601String(),
          'updated_at': item.updatedAt.toUtc().toIso8601String(),
          'dirty': 0,
          'deleted': item.deleted ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final favorites = await api.favorites(includeDeleted: true);
    for (final fav in favorites) {
      final local = await db.query(
        'favorites',
        where: 'user_id = ? AND ol_key = ?',
        whereArgs: [_uid, fav.olKey],
        limit: 1,
      );
      if (local.isNotEmpty && local.first['dirty'] == 1) continue;
      await db.insert(
        'favorites',
        {
          'user_id': _uid,
          'ol_key': fav.olKey,
          'title': fav.title,
          'author': fav.author,
          'cover_id': fav.coverId,
          'created_at': fav.createdAt.toUtc().toIso8601String(),
          'updated_at': fav.updatedAt.toUtc().toIso8601String(),
          'dirty': 0,
          'deleted': fav.deleted ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final history = await api.history();
    for (final entry in history) {
      await db.insert(
        'search_history',
        {
          'id': entry.id,
          'user_id': _uid,
          'query': entry.query,
          'created_at': entry.createdAt.toUtc().toIso8601String(),
          'synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // --- Recomendaciones ------------------------------------------------------
  static const _defaultSubjects = ['fiction', 'science', 'history'];

  /// Regla reproducible: los temas (`subject`) más frecuentes entre favoritos
  /// y biblioteca (peso 2 y 1) y, si faltan, las palabras de las búsquedas
  /// recientes. Se consultan esos temas en Open Library, se excluyen los libros
  /// que el usuario ya tiene y se ordenan por la frecuencia del tema. Sin datos
  /// se usan temas populares y el motivo lo indica.
  Future<RecommendationSet> recommendations({bool refresh = true}) async {
    if (!refresh) {
      final cached = await cachedRecommendations();
      if (cached != null) return cached;
    }
    final owned = <String>{};
    final weights = <String, double>{};
    final favs = await favorites();
    final lib = await library();
    for (final fav in favs) {
      owned.add(fav.olKey);
      await _addSubjects(fav.olKey, 2, weights);
    }
    for (final item in lib) {
      owned.add(item.olKey);
      await _addSubjects(item.olKey, 1, weights);
    }
    final recent = await history();
    final hasSeeds = weights.isNotEmpty || recent.isNotEmpty;

    final ranked = weights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topics = <String, String>{}; // slug -> motivo
    for (final entry in ranked.take(3)) {
      topics[_slug(entry.key)] =
          'Porque tienes libros del tema "${entry.key}" en favoritos o biblioteca';
    }
    if (topics.length < 3) {
      for (final entry in recent.take(5)) {
        final word = _slug(entry.query);
        if (word.isEmpty || word.contains('_')) continue;
        topics.putIfAbsent(
          word,
          () => 'Porque buscaste "${entry.query}"',
        );
        if (topics.length >= 3) break;
      }
    }
    if (topics.length < 3) {
      for (final subject in _defaultSubjects) {
        topics.putIfAbsent(
          subject,
          () => 'Popular en "$subject" (aún no hay suficiente historial)',
        );
        if (topics.length >= 3) break;
      }
    }

    final items = <Recommendation>[];
    final seen = <String>{...owned};
    ApiException? lastError;
    var rank = 0;
    for (final entry in topics.entries) {
      try {
        final books = await openLibrary.subject(entry.key, limit: 12);
        await saveBooks(books);
        var taken = 0;
        for (final book in books) {
          if (book.olKey.isEmpty || !seen.add(book.olKey)) continue;
          items.add(
            Recommendation(
              book: book,
              reason: entry.value,
              score: 1.0 / (rank + 1) - taken * 0.01,
            ),
          );
          if (++taken >= 4) break;
        }
      } on ApiException catch (error) {
        lastError = error;
      }
      rank++;
    }
    if (items.isEmpty) {
      final cached = await cachedRecommendations();
      if (cached != null) return cached;
      if (lastError != null) throw lastError;
    }
    items.sort((a, b) => b.score.compareTo(a.score));
    final criterion = hasSeeds
        ? 'Temas más frecuentes de tus favoritos y biblioteca, más tus últimas búsquedas.'
        : 'Aún no tienes historial ni favoritos: se muestran libros populares por tema.';
    final set = RecommendationSet(
      items: items,
      generatedAt: DateTime.now(),
      criterion: criterion,
    );
    await _saveRecommendations(set);
    return set;
  }

  String _slug(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9áéíóúñ ]'), '')
      .replaceAll(RegExp(r'\s+'), '_');

  Future<void> _addSubjects(
    String olKey,
    double weight,
    Map<String, double> weights,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'books',
      columns: ['subjects'],
      where: 'ol_key = ?',
      whereArgs: [olKey],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final raw = rows.first['subjects'] as String;
    for (final subject in raw.split('|').where((s) => s.isNotEmpty).take(5)) {
      final key = subject.toLowerCase();
      weights[key] = (weights[key] ?? 0) + weight;
    }
  }

  Future<void> _saveRecommendations(RecommendationSet set) async {
    final db = await _database;
    await db.insert(
      'recommendations',
      {
        'user_id': _uid,
        'generated_at': set.generatedAt.toUtc().toIso8601String(),
        'payload': jsonEncode({
          'criterion': set.criterion,
          'items': set.items.map((r) => r.toJson()).toList(),
        }),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<RecommendationSet?> cachedRecommendations() async {
    final db = await _database;
    final rows = await db.query(
      'recommendations',
      where: 'user_id = ?',
      whereArgs: [_uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final data = jsonDecode(rows.first['payload'] as String) as Map;
      return RecommendationSet(
        items: (data['items'] as List)
            .map(
              (r) => Recommendation.fromJson(
                Map<String, dynamic>.from(r as Map),
              ),
            )
            .toList(),
        generatedAt:
            DateTime.parse(rows.first['generated_at'] as String).toLocal(),
        criterion: data['criterion'] as String,
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }
}

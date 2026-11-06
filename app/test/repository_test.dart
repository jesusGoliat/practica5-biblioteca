import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:biblioteca/core/db/app_database.dart';
import 'package:biblioteca/core/models/book.dart';
import 'package:biblioteca/core/network/api_exception.dart';
import 'package:biblioteca/core/network/backend_api.dart';
import 'package:biblioteca/core/network/open_library_api.dart';
import 'package:biblioteca/data/repository.dart';

const _book = Book(
  olKey: '/works/OL1W',
  title: 'Dune',
  authors: ['Frank Herbert'],
  coverId: 7,
  subjects: ['science fiction'],
);

Repository _repo() {
  final offline = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:1',
    connectTimeout: const Duration(milliseconds: 300),
  ));
  return Repository(
    api: BackendApi(baseUrl: 'http://127.0.0.1:1'),
    openLibrary: OpenLibraryApi(dio: offline),
  );
}

void main() {
  sqfliteFfiInit();

  setUp(() async {
    await AppDatabase.instance.close();
    AppDatabase.instance.configureForTests(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() => AppDatabase.instance.close());

  test('favoritos: persisten, se encolan y se pueden quitar', () async {
    final repo = _repo()..userId = 1;
    await repo.setFavorite(_book, true);
    expect((await repo.favorites()).single.title, 'Dune');
    expect((await repo.syncStatus()).pending, 1);

    await repo.setFavorite(_book, false);
    expect(await repo.favorites(), isEmpty);
    expect((await repo.syncStatus()).pending, 2);
  });

  test('biblioteca: alta, cambio de estado y baja generan operaciones', () async {
    final repo = _repo()..userId = 1;
    final item = await repo.addToLibrary(_book, 'want_to_read');
    await repo.updateLibraryItem(item, status: 'reading', rating: 4);
    var items = await repo.library();
    expect(items.single.status, 'reading');
    expect(items.single.rating, 4);

    await repo.deleteLibraryItem(items.single);
    items = await repo.library();
    expect(items, isEmpty);
    expect((await repo.syncStatus()).pending, 3);
  });

  test('los datos están separados por usuario', () async {
    final repo = _repo()..userId = 1;
    await repo.setFavorite(_book, true);
    await repo.addToLibrary(_book, 'read');
    await repo.addHistory('dune');

    repo.userId = 2;
    expect(await repo.favorites(), isEmpty);
    expect(await repo.library(), isEmpty);
    expect(await repo.history(), isEmpty);
    expect((await repo.syncStatus()).pending, 0);
  });

  test('búsqueda sin red usa la caché guardada con su fecha', () async {
    final repo = _repo()..userId = 1;
    final db = await AppDatabase.instance.database;
    await db.insert('search_cache', {
      'user_id': 1,
      'query_key': 'dune',
      'page': 1,
      'payload':
          '{"total":1,"books":[{"key":"/works/OL1W","title":"Dune","author_name":["Frank Herbert"]}]}',
      'fetched_at': '2026-11-01T10:00:00.000Z',
    });

    final outcome = await repo.search('Dune');
    expect(outcome.fromCache, isTrue);
    expect(outcome.books.single.title, 'Dune');
    expect(outcome.error, isNotNull);
    expect(outcome.fetchedAt.toUtc().day, 1);
  });

  test('búsqueda sin red y sin caché falla con error controlado', () async {
    final repo = _repo()..userId = 1;
    await expectLater(repo.search('algo raro'), throwsA(isA<ApiException>()));
    expect((await repo.history()).single.query, 'algo raro');
  });

  test('historial no duplica búsquedas consecutivas iguales', () async {
    final repo = _repo()..userId = 1;
    await repo.addHistory('dune');
    await repo.addHistory('dune');
    await repo.addHistory('emma');
    expect((await repo.history()).map((h) => h.query), ['emma', 'dune']);
  });
}

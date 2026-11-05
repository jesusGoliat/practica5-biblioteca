import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/book.dart';
import 'api_exception.dart';

class SearchResult {
  const SearchResult({
    required this.books,
    required this.total,
    required this.elapsed,
  });

  final List<Book> books;
  final int total;
  final Duration elapsed;
}

/// Cliente de la API pública Open Library (HTTPS, JSON real).
class OpenLibraryApi {
  OpenLibraryApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.openLibraryBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent': AppConfig.userAgent,
                },
              ),
            );

  final Dio _dio;
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _rateLimit() async {
    final since = DateTime.now().difference(_lastRequest);
    if (since < const Duration(milliseconds: 300)) {
      await Future<void>.delayed(
        const Duration(milliseconds: 300) - since,
      );
    }
    _lastRequest = DateTime.now();
  }

  Future<SearchResult> search(String query, {int page = 1, int limit = 20}) async {
    final stopwatch = Stopwatch()..start();
    await _rateLimit();
    try {
      final response = await _dio.get<dynamic>(
        '/search.json',
        queryParameters: {
          'q': query,
          'page': page,
          'limit': limit,
          'fields':
              'key,title,author_name,first_publish_year,cover_i,subject,edition_count',
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const ApiException(
          ApiErrorKind.malformed,
          'Open Library devolvió un formato inesperado.',
        );
      }
      final docs = data['docs'];
      if (docs is! List) {
        throw const ApiException(
          ApiErrorKind.malformed,
          'Open Library no devolvió la lista de resultados.',
        );
      }
      final books = <Book>[];
      var malformed = 0;
      for (final doc in docs) {
        if (doc is! Map) {
          malformed++;
          continue;
        }
        try {
          books.add(Book.fromJson(Map<String, dynamic>.from(doc)));
        } catch (_) {
          malformed++;
        }
      }
      stopwatch.stop();
      if (books.isEmpty && malformed > 0) {
        throw const ApiException(
          ApiErrorKind.malformed,
          'Los resultados de Open Library están malformados.',
        );
      }
      return SearchResult(
        books: books,
        total: (data['numFound'] as num?)?.toInt() ?? books.length,
        elapsed: stopwatch.elapsed,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException catch (error) {
      throw ApiException(
        ApiErrorKind.malformed,
        'JSON inválido de Open Library: ${error.message}',
      );
    }
  }

  Future<Book> work(String olKey) async {
    await _rateLimit();
    try {
      final response = await _dio.get<dynamic>('$olKey.json');
      final data = response.data;
      if (data is! Map) {
        throw const ApiException(
          ApiErrorKind.malformed,
          'Open Library devolvió un detalle inesperado.',
        );
      }
      return Book.fromJson(
        Map<String, dynamic>.from(data),
        fallbackKey: olKey,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException catch (error) {
      throw ApiException(
        ApiErrorKind.malformed,
        'Detalle de Open Library malformado: ${error.message}',
      );
    }
  }

  /// Obras de un tema, usadas por el motor de recomendaciones.
  Future<List<Book>> subject(String subjectSlug, {int limit = 20}) async {
    await _rateLimit();
    try {
      final response = await _dio.get<dynamic>(
        '/subjects/$subjectSlug.json',
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      if (data is! Map || data['works'] is! List) {
        throw const ApiException(
          ApiErrorKind.malformed,
          'Open Library devolvió un tema inesperado.',
        );
      }
      final books = <Book>[];
      for (final work in data['works'] as List) {
        if (work is Map) {
          books.add(Book.fromJson(Map<String, dynamic>.from(work)));
        }
      }
      return books;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException catch (error) {
      throw ApiException(
        ApiErrorKind.malformed,
        'Tema de Open Library malformado: ${error.message}',
      );
    }
  }
}

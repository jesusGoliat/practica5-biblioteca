import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/favorite_book.dart';
import '../models/history_entry.dart';
import '../models/library_item.dart';
import 'api_exception.dart';

class BackendApi {
  BackendApi({String? baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 10),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'User-Agent': AppConfig.userAgent,
            },
          ),
        );

  final Dio _dio;
  void Function()? onUnauthorized;

  String get baseUrl => _dio.options.baseUrl;

  void setToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<Map<String, dynamic>> _map(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const ApiException(
        ApiErrorKind.malformed,
        'El servidor devolvió una respuesta inesperada.',
      );
    } on DioException catch (error) {
      final mapped = ApiException.fromDio(error);
      if (mapped.kind == ApiErrorKind.unauthorized) {
        onUnauthorized?.call();
      }
      throw mapped;
    } on FormatException catch (error) {
      throw ApiException(
        ApiErrorKind.malformed,
        'Los datos recibidos están malformados: ${error.message}',
      );
    }
  }

  Future<List<dynamic>> _list(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is List) return data;
      throw const ApiException(
        ApiErrorKind.malformed,
        'El servidor devolvió una lista inesperada.',
      );
    } on DioException catch (error) {
      final mapped = ApiException.fromDio(error);
      if (mapped.kind == ApiErrorKind.unauthorized) {
        onUnauthorized?.call();
      }
      throw mapped;
    }
  }

  Future<bool> health() async {
    try {
      await _dio.get<dynamic>('/health', options: Options(extra: {'auth': false}));
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- Autenticación -------------------------------------------------------
  Future<AppUser> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final body = await _map(
      () => _dio.post<dynamic>(
        '/auth/register',
        data: {'username': email, 'email': email, 'password': password, 'name': name},
      ),
    );
    return AppUser.fromJson(body);
  }

  Future<({String token, AppUser user})> login({
    required String email,
    required String password,
  }) async {
    final body = await _map(
      () => _dio.post<dynamic>(
        '/auth/login',
        data: {'username': email, 'password': password},
      ),
    );
    return (
      token: body['access_token'] as String,
      user: AppUser.fromJson(body['user'] as Map<String, dynamic>),
    );
  }

  Future<({String token, AppUser user})> loginWithGoogle(String idToken) async {
    final body = await _map(
      () => _dio.post<dynamic>(
        '/auth/google',
        data: {'id_token': idToken},
      ),
    );
    return (
      token: body['access_token'] as String,
      user: AppUser.fromJson(body['user'] as Map<String, dynamic>),
    );
  }

  Future<AppUser> me() async {
    final body = await _map(() => _dio.get<dynamic>('/auth/me'));
    return AppUser.fromJson(body);
  }

  Future<void> logout() async {
    try {
      await _dio.post<dynamic>('/auth/logout');
    } catch (_) {
      // El cierre local es suficiente si el servidor no responde.
    }
  }

  // --- Biblioteca ----------------------------------------------------------
  Future<List<LibraryItem>> library({bool includeDeleted = false}) async {
    final data = await _list(
      () => _dio.get<dynamic>(
        '/library',
        queryParameters: {'include_deleted': includeDeleted},
      ),
    );
    return data
        .whereType<Map>()
        .map((json) => LibraryItem.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<LibraryItem> createLibraryItem(Map<String, dynamic> data) async {
    final body = await _map(
      () => _dio.post<dynamic>('/library', data: data),
    );
    return LibraryItem.fromJson(body);
  }

  Future<LibraryItem> updateLibraryItem(
    String publicId,
    Map<String, dynamic> data,
  ) async {
    final body = await _map(
      () => _dio.put<dynamic>('/library/$publicId', data: data),
    );
    return LibraryItem.fromJson(body);
  }

  Future<void> deleteLibraryItem(String publicId) async {
    await _map(() => _dio.delete<dynamic>('/library/$publicId'));
  }

  // --- Favoritos -----------------------------------------------------------
  Future<List<FavoriteBook>> favorites({bool includeDeleted = false}) async {
    final data = await _list(
      () => _dio.get<dynamic>(
        '/favorites',
        queryParameters: {'include_deleted': includeDeleted},
      ),
    );
    return data
        .whereType<Map>()
        .map((json) => FavoriteBook.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<FavoriteBook> setFavorite(Map<String, dynamic> data) async {
    final body = await _map(
      () => _dio.put<dynamic>('/favorites', data: data),
    );
    return FavoriteBook.fromJson(body);
  }

  // --- Historial -----------------------------------------------------------
  Future<List<HistoryEntry>> history() async {
    final data = await _list(() => _dio.get<dynamic>('/history'));
    return data
        .whereType<Map>()
        .map((json) => HistoryEntry.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<HistoryEntry> addHistory(Map<String, dynamic> data) async {
    final body = await _map(
      () => _dio.post<dynamic>('/history', data: data),
    );
    return HistoryEntry.fromJson(body);
  }

  Future<void> clearHistory() async {
    await _map(() => _dio.delete<dynamic>('/history'));
  }

  // --- Sync ----------------------------------------------------------------
  Future<Map<String, dynamic>> sync(List<Map<String, dynamic>> operations) async {
    return _map(
      () => _dio.post<dynamic>('/sync', data: {'operations': operations}),
    );
  }

  // --- Admin ---------------------------------------------------------------
  Future<List<Map<String, dynamic>>> adminUsers() async {
    final data = await _list(() => _dio.get<dynamic>('/admin/users'));
    return data
        .whereType<Map>()
        .map((json) => Map<String, dynamic>.from(json))
        .toList();
  }

  Future<List<HistoryEntry>> adminHistory(int userId) async {
    final data = await _list(
      () => _dio.get<dynamic>('/admin/users/$userId/history'),
    );
    return data
        .whereType<Map>()
        .map((json) => HistoryEntry.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<List<FavoriteBook>> adminFavorites(int userId) async {
    final data = await _list(
      () => _dio.get<dynamic>('/admin/users/$userId/favorites'),
    );
    return data
        .whereType<Map>()
        .map((json) => FavoriteBook.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
}

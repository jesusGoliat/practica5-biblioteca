import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/config/app_config.dart';
import '../core/models/app_user.dart';
import '../core/network/api_exception.dart';
import '../core/network/backend_api.dart';
import '../data/repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required this.api,
    required this.repository,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage() {
    api.onUnauthorized = _expireSession;
  }

  final BackendApi api;
  final Repository repository;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'jwt_token';
  static const _userKey = 'session_user';

  AppUser? currentUser;
  bool initialized = false;
  bool isLoading = false;
  String? error;
  bool sessionExpired = false;
  bool _googleReady = false;

  bool get isLoggedIn => currentUser != null;

  /// Restaura la sesión guardada. Sin red se conserva la sesión ya validada.
  Future<void> init() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final rawUser = await _storage.read(key: _userKey);
      if (token != null && rawUser != null) {
        api.setToken(token);
        currentUser = AppUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawUser) as Map),
        );
        repository.userId = currentUser!.id;
        try {
          final fresh = await api.me();
          await _persistUser(fresh);
          currentUser = fresh;
        } on ApiException catch (e) {
          if (e.kind == ApiErrorKind.unauthorized) await _clear();
        }
      }
    } catch (_) {
      await _clear();
    }
    initialized = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) => _run(() async {
        final result = await api.login(
          email: email.trim(),
          password: password,
        );
        await _startSession(result.token, result.user);
      });

  Future<bool> register(String email, String password, String? name) =>
      _run(() async {
        final cleanName = name?.trim();
        await api.register(
          email: email.trim(),
          password: password,
          name: (cleanName == null || cleanName.isEmpty) ? null : cleanName,
        );
        final result = await api.login(
          email: email.trim(),
          password: password,
        );
        await _startSession(result.token, result.user);
      });

  Future<bool> loginWithGoogle() => _run(() async {
        if (!AppConfig.hasGoogleWeb) {
          throw const ApiException(
            ApiErrorKind.badRequest,
            'Google Sign-In no está configurado en esta compilación '
            '(falta GOOGLE_WEB_CLIENT_ID).',
          );
        }
        if (!_googleReady) {
          await GoogleSignIn.instance.initialize(
            serverClientId: AppConfig.googleWebClientId,
            clientId: defaultTargetPlatform == TargetPlatform.iOS &&
                    AppConfig.hasGoogleIos
                ? AppConfig.googleIosClientId
                : null,
          );
          _googleReady = true;
        }
        try {
          final account = await GoogleSignIn.instance.authenticate();
          final idToken = account.authentication.idToken;
          if (idToken == null) {
            throw const ApiException(
              ApiErrorKind.badRequest,
              'Google no devolvió un token de identidad.',
            );
          }
          final result = await api.loginWithGoogle(idToken);
          await _startSession(result.token, result.user);
        } on GoogleSignInException catch (e) {
          throw ApiException(
            ApiErrorKind.badRequest,
            e.code == GoogleSignInExceptionCode.canceled
                ? 'Inicio con Google cancelado.'
                : 'No se pudo iniciar con Google (${e.code.name}).',
          );
        }
      });

  Future<void> logout() async {
    await api.logout();
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _clear();
    notifyListeners();
  }

  void clearError() {
    error = null;
    sessionExpired = false;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (e) {
      error = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _startSession(String token, AppUser user) async {
    api.setToken(token);
    await _storage.write(key: _tokenKey, value: token);
    await _persistUser(user);
    currentUser = user;
    sessionExpired = false;
    repository.userId = user.id;
  }

  Future<void> _persistUser(AppUser user) =>
      _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  Future<void> _clear() async {
    api.setToken(null);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    currentUser = null;
    repository.userId = null;
  }

  void _expireSession() {
    if (currentUser == null) return;
    _clear().then((_) {
      sessionExpired = true;
      error = 'Tu sesión expiró. Inicia sesión de nuevo.';
      notifyListeners();
    });
  }
}

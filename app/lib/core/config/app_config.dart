import 'package:flutter/foundation.dart';

/// Configuración de compilación. Los valores se pasan con `--dart-define`
/// (ver `dart_defines.example.json`). Ningún secreto vive en el repositorio.
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  static const String openLibraryBaseUrl = 'https://openlibrary.org';
  static const String coversBaseUrl = 'https://covers.openlibrary.org';
  static const String userAgent =
      'Practica5-Biblioteca/1.0 (+https://github.com/jesusGoliat/practica5-biblioteca)';

  /// Credenciales de demostración para el job de iOS (no se commitean).
  static const String demoEmail = String.fromEnvironment('DEMO_EMAIL');
  static const String demoPassword = String.fromEnvironment('DEMO_PASSWORD');
  static const String demoScreen = String.fromEnvironment('DEMO_SCREEN');

  static const bool allowHttp = bool.fromEnvironment(
    'ALLOW_HTTP',
    defaultValue: true,
  );

  static bool get hasGoogleWeb => googleWebClientId.isNotEmpty;
  static bool get hasGoogleIos => googleIosClientId.isNotEmpty;

  /// En release sólo se permite HTTPS para la comunicación remota.
  static void validate() {
    if (kReleaseMode && !apiBaseUrl.startsWith('https://')) {
      throw StateError(
        'En release API_BASE_URL debe usar HTTPS. '
        'Recibido: $apiBaseUrl',
      );
    }
  }
}

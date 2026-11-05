import 'package:dio/dio.dart';

enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  badRequest,
  server,
  malformed,
  unknown,
}

class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  bool get isOffline =>
      kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;

  bool get isConfiguration =>
      message.toLowerCase().contains('google') ||
      message.toLowerCase().contains('configur');

  factory ApiException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String detail = '';
    if (data is Map && data['detail'] is String) {
      detail = data['detail'] as String;
    } else if (data is String) {
      detail = data;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          ApiErrorKind.timeout,
          'La operación tardó demasiado. Revisa tu conexión e inténtalo de nuevo.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          ApiErrorKind.network,
          'Sin conexión con el servidor. Se muestran los datos guardados.',
        );
      case DioExceptionType.badResponse:
        if (status == 401) {
          return ApiException(
            ApiErrorKind.unauthorized,
            detail.isNotEmpty ? detail : 'La sesión expiró. Inicia sesión de nuevo.',
            statusCode: status,
          );
        }
        if (status == 403) {
          return ApiException(
            ApiErrorKind.forbidden,
            detail.isNotEmpty ? detail : 'No tienes permiso para esta acción.',
            statusCode: status,
          );
        }
        if (status == 404) {
          return ApiException(
            ApiErrorKind.notFound,
            detail.isNotEmpty ? detail : 'El recurso no existe.',
            statusCode: status,
          );
        }
        if (status != null && status >= 500) {
          return ApiException(
            ApiErrorKind.server,
            detail.isNotEmpty ? detail : 'El servidor falló. Inténtalo más tarde.',
            statusCode: status,
          );
        }
        return ApiException(
          ApiErrorKind.badRequest,
          detail.isNotEmpty ? detail : 'La solicitud no es válida.',
          statusCode: status,
        );
      case DioExceptionType.cancel:
        return const ApiException(ApiErrorKind.unknown, 'Solicitud cancelada.');
      case DioExceptionType.badCertificate:
        return const ApiException(
          ApiErrorKind.network,
          'El certificado HTTPS no es válido.',
        );
      case DioExceptionType.unknown:
        return ApiException(
          ApiErrorKind.network,
          error.message ?? 'No se pudo conectar con el servidor.',
        );
    }
  }

  @override
  String toString() => message;
}

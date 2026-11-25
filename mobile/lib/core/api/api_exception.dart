import 'package:dio/dio.dart';

/// User-facing error mapped from an HTTP ProblemDetails (RFC 9457) response
/// or a network/transport failure.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.title,
    this.detail,
    this.validationErrors,
  });

  /// Creates an [ApiException] from a decoded ProblemDetails JSON object.
  factory ApiException.fromProblemDetails(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    final parsedStatus = statusCode ?? (json['status'] as num?)?.toInt();
    final title = _nonEmptyString(json['title']);
    final detail = _nonEmptyString(json['detail']);
    final validationErrors = _parseValidationErrors(json['errors']);

    final message = detail ??
        _firstValidationMessage(validationErrors) ??
        _defaultMessageForStatus(parsedStatus);

    return ApiException(
      message: message,
      statusCode: parsedStatus,
      title: title,
      detail: detail,
      validationErrors: validationErrors,
    );
  }

  /// Maps a [DioException] into an [ApiException] with a Spanish user message.
  factory ApiException.fromDioException(DioException error) {
    final inner = error.error;
    if (inner is ApiException) {
      return inner;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          message:
              'La conexión está tardando demasiado. Comprueba tu red e inténtalo de nuevo.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message:
              'No se ha podido conectar con el servidor. Comprueba tu conexión a internet.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          message: 'La petición se ha cancelado.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          message: 'Error de seguridad en la conexión con el servidor.',
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        if (data is Map<String, dynamic>) {
          return ApiException.fromProblemDetails(data, statusCode: statusCode);
        }
        if (data is Map) {
          return ApiException.fromProblemDetails(
            Map<String, dynamic>.from(data),
            statusCode: statusCode,
          );
        }
        return ApiException(
          statusCode: statusCode,
          message: _defaultMessageForStatus(statusCode),
        );
      case DioExceptionType.unknown:
        return const ApiException(
          message: 'Ha ocurrido un error inesperado. Inténtalo de nuevo.',
        );
    }
  }

  final int? statusCode;

  /// Spanish message ready to display to the user.
  final String message;

  final String? title;
  final String? detail;
  final Map<String, List<String>>? validationErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;

  static String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, List<String>>? _parseValidationErrors(Object? raw) {
    if (raw is! Map) return null;
    final result = <String, List<String>>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is List) {
        final messages = value
            .map((item) => item?.toString().trim() ?? '')
            .where((text) => text.isNotEmpty)
            .toList();
        if (messages.isNotEmpty) {
          result[key] = messages;
        }
      }
    }
    return result.isEmpty ? null : result;
  }

  static String? _firstValidationMessage(Map<String, List<String>>? errors) {
    if (errors == null || errors.isEmpty) return null;
    for (final list in errors.values) {
      if (list.isNotEmpty) return list.first;
    }
    return null;
  }

  static String _defaultMessageForStatus(int? statusCode) {
    return switch (statusCode) {
      400 => 'Los datos enviados no son válidos.',
      401 => 'Tu sesión ha caducado. Vuelve a iniciar sesión.',
      403 => 'No tienes permisos para hacer esta acción.',
      404 => 'No se ha encontrado el elemento solicitado.',
      409 => 'No se ha podido completar la acción por un conflicto con el estado actual.',
      final code when code != null && code >= 500 =>
        'El servidor ha tenido un problema. Inténtalo de nuevo más tarde.',
      _ => 'Ha ocurrido un error inesperado. Inténtalo de nuevo.',
    };
  }
}

/// Returns a Spanish message suitable for UI display from any thrown error.
String userErrorMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Ha ocurrido un error inesperado. Inténtalo de nuevo.';
}

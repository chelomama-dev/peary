import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peary/core/api/api_client.dart';
import 'package:peary/core/api/api_exception.dart';
import 'package:peary/core/auth/authenticator.dart';

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ApiException.fromProblemDetails', () {
    test('uses Spanish detail when present', () {
      final ex = ApiException.fromProblemDetails(
        {
          'type': 'https://tools.ietf.org/html/rfc9110#section-15.5.10',
          'title': 'Conflict',
          'status': 409,
          'detail': 'No puedes dejar el grupo sin administradores.',
        },
        statusCode: 409,
      );

      expect(ex.statusCode, 409);
      expect(ex.isConflict, isTrue);
      expect(ex.title, 'Conflict');
      expect(ex.detail, 'No puedes dejar el grupo sin administradores.');
      expect(ex.message, 'No puedes dejar el grupo sin administradores.');
    });

    test('parses 400 validation errors and falls back to first message', () {
      final ex = ApiException.fromProblemDetails(
        {
          'title': 'One or more validation errors occurred.',
          'status': 400,
          'errors': {
            'title': ['El título es obligatorio.'],
            'dueTime': ['Se requiere fecha.'],
          },
        },
        statusCode: 400,
      );

      expect(ex.statusCode, 400);
      expect(ex.validationErrors, {
        'title': ['El título es obligatorio.'],
        'dueTime': ['Se requiere fecha.'],
      });
      expect(ex.message, 'El título es obligatorio.');
    });

    test('falls back to generic Spanish message when detail is absent or blank', () {
      final notFound = ApiException.fromProblemDetails(
        {'title': 'Not Found', 'status': 404, 'detail': '   '},
      );
      expect(notFound.statusCode, 404);
      expect(notFound.isNotFound, isTrue);
      expect(notFound.message, 'No se ha encontrado el elemento solicitado.');

      final serverError = ApiException.fromProblemDetails(
        {'title': 'Internal Server Error', 'status': 500},
      );
      expect(serverError.statusCode, 500);
      expect(
        serverError.message,
        'El servidor ha tenido un problema. Inténtalo de nuevo más tarde.',
      );
    });
  });

  group('ApiException.fromDioException', () {
    final requestOptions = RequestOptions(path: '/api/me');

    test('maps badResponse with ProblemDetails body', () {
      final dioError = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 404,
          data: {
            'type': 'https://tools.ietf.org/html/rfc9110#section-15.5.5',
            'title': 'Not Found',
            'status': 404,
            'detail': 'Task 3f2c was not found.',
          },
        ),
      );

      final ex = ApiException.fromDioException(dioError);
      expect(ex.statusCode, 404);
      expect(ex.isNotFound, isTrue);
      expect(ex.message, 'Task 3f2c was not found.');
    });

    test('maps timeouts and connection errors to Spanish messages', () {
      final timeoutEx = ApiException.fromDioException(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      expect(timeoutEx.message, contains('tardando demasiado'));

      final connEx = ApiException.fromDioException(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionError,
        ),
      );
      expect(connEx.message, contains('No se ha podido conectar'));
    });
  });

  group('createDio auth interceptor', () {
    test('attaches Bearer token when authenticator provides one', () async {
      final adapter = _CapturingAdapter();
      final dio = createDio(
        baseUrl: 'http://10.0.2.2:5080',
        authenticator: FakeAuthenticator(accessToken: 'test-token-123'),
        httpClientAdapter: adapter,
      );

      await dio.get<Map<String, dynamic>>('/api/me');

      expect(
        adapter.lastOptions?.headers['Authorization'],
        'Bearer test-token-123',
      );
    });

    test('omits Authorization header when authenticator returns null', () async {
      final adapter = _CapturingAdapter();
      final dio = createDio(
        baseUrl: 'http://10.0.2.2:5080',
        authenticator: FakeAuthenticator(),
        httpClientAdapter: adapter,
      );

      await dio.get<Map<String, dynamic>>('/api/me');

      expect(adapter.lastOptions?.headers.containsKey('Authorization'), isFalse);
    });
  });
}

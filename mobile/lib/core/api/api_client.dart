import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/authenticator.dart';
import '../config.dart';
import 'api_exception.dart';

/// Builds the configured [Dio] instance.
///
/// This is the single place that attaches `Authorization: Bearer <token>`.
Dio createDio({
  required String baseUrl,
  required Authenticator authenticator,
  HttpClientAdapter? httpClientAdapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
      },
    ),
  );

  if (httpClientAdapter != null) {
    dio.httpClientAdapter = httpClientAdapter;
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await authenticator.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
}

/// Thin HTTP client wrapping [Dio] so every transport or ProblemDetails error
/// surfaces consistently as an [ApiException].
class ApiClient {
  const ApiClient(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _guard(() async {
      final response = await dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return _requireJsonMap(response);
    });
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? data,
  }) async {
    return _guard(() async {
      final response = await dio.post<Map<String, dynamic>>(
        path,
        data: data,
      );
      return _requireJsonMap(response);
    });
  }

  Future<void> postNoContent(
    String path, {
    Object? data,
  }) async {
    return _guard(() async {
      await dio.post<void>(path, data: data);
    });
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? data,
  }) async {
    return _guard(() async {
      final response = await dio.patch<Map<String, dynamic>>(
        path,
        data: data,
      );
      return _requireJsonMap(response);
    });
  }

  Future<void> putNoContent(
    String path, {
    Object? data,
  }) async {
    return _guard(() async {
      await dio.put<void>(path, data: data);
    });
  }

  Future<void> deleteNoContent(String path) async {
    return _guard(() async {
      await dio.delete<void>(path);
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Map<String, dynamic> _requireJsonMap(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data == null) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'La respuesta del servidor llegó vacía.',
      );
    }
    return data;
  }
}

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final authenticator = ref.watch(authenticatorProvider);
  return createDio(
    baseUrl: config.apiBaseUrl,
    authenticator: authenticator,
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

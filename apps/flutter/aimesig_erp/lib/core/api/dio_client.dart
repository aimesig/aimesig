// lib/core/api/dio_client.dart

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_constants.dart';

class DioClient {
  DioClient._();

  static Dio? _dio;
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  static Dio get instance {
    _dio ??= _createDio();
    return _dio!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(dio),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => debugPrint(o.toString()),
      ),
    ]);

    return dio;
  }

  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> getToken() =>
      _storage.read(key: _tokenKey);

  static Future<void> clearToken() =>
      _storage.delete(key: _tokenKey);
}

/// Attaches Bearer token and handles 401 → refresh → retry
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await DioClient.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      try {
        final token = await DioClient.getToken();
        if (token == null) return handler.next(err);

        final resp = await _dio.post(
          ApiConstants.refresh,
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            extra: {'skipAuthRefresh': true},
          ),
        );
        final newToken = resp.data['token'] as String;
        await DioClient.saveToken(newToken);

        // Retry original request with new token
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        final retried = await _dio.fetch(opts);
        return handler.resolve(retried);
      } catch (_) {
        await DioClient.clearToken();
        // The router will redirect to login when token is null
        return handler.next(err);
      }
    }
    handler.next(err);
  }
}

// ignore: avoid_print
void debugPrint(String msg) => print(msg);

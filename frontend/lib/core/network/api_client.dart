import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

Dio createDio() {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        // Try to refresh token
        final refreshed = await _tryRefreshToken(error.requestOptions);
        if (refreshed != null) return handler.resolve(refreshed);
        // Clear tokens and signal logout
        await _storage.deleteAll();
      }
      return handler.next(error);
    },
  ));

  return dio;
}

Future<Response?> _tryRefreshToken(RequestOptions options) async {
  try {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null) return null;
    final dio = Dio(BaseOptions(baseUrl: _baseUrl));
    final resp = await dio.post(
      '/api/v1/auth/refresh',
      data: {'refresh_token': refresh},
    );
    final newToken = resp.data['access_token'] as String;
    await _storage.write(key: 'access_token', value: newToken);
    options.headers['Authorization'] = 'Bearer $newToken';
    return await dio.fetch(options);
  } catch (_) {
    return null;
  }
}

final dioProvider = Provider<Dio>((ref) => createDio());

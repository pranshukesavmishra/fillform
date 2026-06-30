import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/api_client.dart';

class AuthService {
  final Dio _dio;
  static const _storage = FlutterSecureStorage();

  AuthService(this._dio);

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final resp = await _dio.post('/api/v1/auth/otp/send', data: {'phone': phone});
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final resp = await _dio.post('/api/v1/auth/otp/verify', data: {
      'phone': phone,
      'otp': otp,
    });
    final data = resp.data as Map<String, dynamic>;
    await _storage.write(key: 'access_token', value: data['access_token'] as String);
    await _storage.write(key: 'refresh_token', value: data['refresh_token'] as String);
    return data;
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/v1/auth/logout');
    } catch (_) {}
    await _storage.deleteAll();
  }

  Future<String?> getToken() => _storage.read(key: 'access_token');

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(dioProvider)),
);

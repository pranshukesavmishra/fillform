import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/auth_service.dart';

String _extractErrorMessage(Object e, String fallback) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
  }
  return fallback;
}

enum AuthStep { idle, sendingOtp, otpSent, verifying, success, error }

class AuthState {
  final AuthStep step;
  final String? phone;
  final String? error;
  final bool isLoggedIn;

  const AuthState({
    this.step = AuthStep.idle,
    this.phone,
    this.error,
    this.isLoggedIn = false,
  });

  AuthState copyWith({AuthStep? step, String? phone, String? error, bool? isLoggedIn}) {
    return AuthState(
      step: step ?? this.step,
      phone: phone ?? this.phone,
      error: error ?? this.error,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;

  AuthNotifier(this._service) : super(const AuthState()) {
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final loggedIn = await _service.isLoggedIn();
    state = state.copyWith(isLoggedIn: loggedIn);
  }

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(step: AuthStep.sendingOtp, error: null, phone: phone);
    try {
      await _service.sendOtp(phone);
      state = state.copyWith(step: AuthStep.otpSent);
    } catch (e) {
      state = state.copyWith(
        step: AuthStep.error,
        error: _extractErrorMessage(e, e.toString()),
      );
    }
  }

  Future<bool> verifyOtp(String otp) async {
    state = state.copyWith(step: AuthStep.verifying, error: null);
    try {
      await _service.verifyOtp(state.phone!, otp);
      state = state.copyWith(step: AuthStep.success, isLoggedIn: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        step: AuthStep.error,
        error: _extractErrorMessage(e, 'Invalid OTP. Please try again.'),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _service.logout();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authServiceProvider)),
);

final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(authServiceProvider);
  return service.isLoggedIn();
});

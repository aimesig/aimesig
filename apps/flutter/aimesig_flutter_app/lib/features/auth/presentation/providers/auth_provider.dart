import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/firebase_auth_service.dart';

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>(
  (_) => FirebaseAuthService(),
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthServiceProvider).authStateChanges;
});

enum AuthStatus { idle, loading, otpSent, success, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? verificationId;
  final String? phoneNumber;

  const AuthState({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.verificationId,
    this.phoneNumber,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? verificationId,
    String? phoneNumber,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      verificationId: verificationId ?? this.verificationId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  late final FirebaseAuthService _service;

  @override
  AuthState build() {
    _service = ref.read(firebaseAuthServiceProvider);
    return const AuthState();
  }

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(status: AuthStatus.loading, phoneNumber: phoneNumber);
    await _service.sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId) {
        state = state.copyWith(
          status: AuthStatus.otpSent,
          verificationId: verificationId,
        );
      },
      onError: (error) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: error,
        );
      },
    );
  }

  Future<void> resendOtp() async {
    if (state.phoneNumber != null) await sendOtp(state.phoneNumber!);
  }

  Future<bool> verifyOtp(String smsCode) async {
    if (state.verificationId == null) return false;
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _service.verifyOtp(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );
      state = state.copyWith(status: AuthStatus.success);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyError(e),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = const AuthState();
  }

  void resetError() => state = state.copyWith(status: AuthStatus.idle);

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid OTP. Please try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }
}
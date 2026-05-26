import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/secure_storage.dart';
import '../../data/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, bool>((ref) {
  return AuthController(
    ref.read(authServiceProvider),
  );
});

class AuthController extends StateNotifier<bool> {
  final AuthService authService;

  AuthController(this.authService) : super(false);

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      state = true;

      final response = await authService.login(
        email: email,
        password: password,
      );

      await SecureStorage.saveAccessToken(
        response.data['accessToken'],
      );

      await SecureStorage.saveRefreshToken(
        response.data['refreshToken'],
      );

      state = false;

      return true;
    } catch (e) {
      state = false;
      return false;
    }
  }
}
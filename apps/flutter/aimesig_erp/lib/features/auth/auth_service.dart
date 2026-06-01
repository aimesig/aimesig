// lib/features/auth/auth_service.dart

import 'package:dio/dio.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/dio_client.dart';
import '../../core/models/user_model.dart';

class AuthService {
  final Dio _dio = DioClient.instance;

  // ── Login ─────────────────────────────────────────────────────────
  Future<({UserModel user, String token})> login({
    required String email,
    required String password,
    String? tenantSlug,
  }) async {
    final resp = await _dio.post(ApiConstants.login, data: {
      'email':    email,
      'password': password,
      if (tenantSlug != null) 'tenant_slug': tenantSlug,
    });
    final token = resp.data['token'] as String;
    final user  = UserModel.fromJson(resp.data['user'] as Map<String, dynamic>);
    await DioClient.saveToken(token);
    return (user: user, token: token);
  }

  // ── Register ──────────────────────────────────────────────────────
  Future<({UserModel user, String token, TenantModel tenant})> register({
    required String orgName,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    String? orgType,
    String? timezone,
    String? currency,
  }) async {
    final resp = await _dio.post(ApiConstants.register, data: {
      'org_name':       orgName,
      'admin_name':     adminName,
      'admin_email':    adminEmail,
      'admin_password': adminPassword,
      if (orgType  != null) 'org_type':  orgType,
      if (timezone != null) 'timezone':  timezone,
      if (currency != null) 'currency':  currency,
    });
    final token      = resp.data['token'] as String;
    final tenantJson = resp.data['tenant'] as Map<String, dynamic>;
    final userJson   = Map<String, dynamic>.from(resp.data['user'] as Map<String, dynamic>);
    userJson['tenant_id'] ??= tenantJson['id'];
    final user   = UserModel.fromJson(userJson);
    final tenant = TenantModel.fromJson(tenantJson);
    await DioClient.saveToken(token);
    return (user: user, token: token, tenant: tenant);
  }

  // ── Password ──────────────────────────────────────────────────────
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post(ApiConstants.changePassword, data: {
      'current_password': currentPassword,
      'new_password':     newPassword,
    });
  }

  Future<({String email, String temporaryPassword})> adminResetPassword(
      String userId) async {
    final resp = await _dio.post('${ApiConstants.auth}/reset-password-by-admin',
        data: {'user_id': userId});
    return (
      email: resp.data['user']['email'] as String,
      temporaryPassword: resp.data['temporary_password'] as String,
    );
  }

  // ── Provisioning (admin only) ─────────────────────────────────────
  Future<({String email, String temporaryPassword})> provisionStaff(
      String staffId) async {
    final resp = await _dio.post(ApiConstants.provisionStaff,
        data: {'staff_id': staffId});
    return (
      email: resp.data['user']['email'] as String,
      temporaryPassword: resp.data['temporary_password'] as String,
    );
  }

  Future<({String email, String temporaryPassword})> provisionMember(
      String memberId) async {
    final resp = await _dio.post(ApiConstants.provisionMember,
        data: {'member_id': memberId});
    return (
      email: resp.data['user']['email'] as String,
      temporaryPassword: resp.data['temporary_password'] as String,
    );
  }

  Future<List<dynamic>> listUsers() async {
    final resp = await _dio.get(ApiConstants.authUsers);
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> setUserActive(String userId,
      {required bool isActive}) async {
    final resp = await _dio.patch('${ApiConstants.authUsers}/$userId',
        data: {'is_active': isActive});
    return resp.data as Map<String, dynamic>;
  }

  // ── Misc ──────────────────────────────────────────────────────────
  Future<void> logout() => DioClient.clearToken();

  Future<bool> isLoggedIn() async {
    final t = await DioClient.getToken();
    return t != null;
  }
}
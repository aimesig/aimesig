// lib/features/members/members_service.dart

import 'package:dio/dio.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/dio_client.dart';

class MembersService {
  final Dio _dio = DioClient.instance;

  // ── List ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMembers({
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final resp = await _dio.get(ApiConstants.members, queryParameters: {
      if (status != null) 'status': status,
      if (search != null) 'search': search,
      'page': page,
      'limit': limit,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ── Create ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createMember(Map<String, dynamic> data) async {
    final resp = await _dio.post(ApiConstants.members, data: data);
    return resp.data as Map<String, dynamic>;
  }

  // ── Get single ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMember(String id) async {
    final resp = await _dio.get('${ApiConstants.members}/$id');
    return resp.data as Map<String, dynamic>;
  }

  // ── Update ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> updateMember(
    String id,
    Map<String, dynamic> data,
  ) async {
    final resp = await _dio.patch('${ApiConstants.members}/$id', data: data);
    return resp.data as Map<String, dynamic>;
  }

  // ── Delete ──────────────────────────────────────────────────────
  Future<void> deleteMember(String id) =>
      _dio.delete('${ApiConstants.members}/$id');

  // ── Enrollments ──────────────────────────────────────────────────
  Future<List<dynamic>> getMemberEnrollments(String memberId) async {
    final resp =
        await _dio.get('${ApiConstants.members}/$memberId/enrollments');
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> enrollMember(
    String memberId,
    String batchId,
  ) async {
    final resp = await _dio.post(
      '${ApiConstants.members}/$memberId/enroll',
      data: {'batch_id': batchId},
    );
    return resp.data as Map<String, dynamic>;
  }

  // ── Payments ────────────────────────────────────────────────────
  Future<List<dynamic>> getMemberPayments(String memberId) async {
    final resp =
        await _dio.get('${ApiConstants.members}/$memberId/payments');
    return resp.data as List<dynamic>;
  }
}

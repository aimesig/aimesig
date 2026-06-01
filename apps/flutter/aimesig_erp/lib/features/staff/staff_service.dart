// lib/features/staff/staff_service.dart

import 'package:dio/dio.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/dio_client.dart';

class StaffService {
  final Dio _dio = DioClient.instance;

  Future<List<dynamic>> getStaff({String? status, String? search}) async {
    final resp = await _dio.get(ApiConstants.staff, queryParameters: {
      if (status != null) 'status': status,
      if (search != null) 'search': search,
    });
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createStaff(
      Map<String, dynamic> data) async {
    final resp = await _dio.post(ApiConstants.staff, data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStaffMember(String id) async {
    final resp = await _dio.get('${ApiConstants.staff}/$id');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateStaff(
      String id, Map<String, dynamic> data) async {
    final resp =
        await _dio.patch('${ApiConstants.staff}/$id', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteStaff(String id) =>
      _dio.delete('${ApiConstants.staff}/$id');

  Future<List<dynamic>> getStaffSchedule(String id) async {
    final resp =
        await _dio.get('${ApiConstants.staff}/$id/schedule');
    return resp.data as List<dynamic>;
  }
}

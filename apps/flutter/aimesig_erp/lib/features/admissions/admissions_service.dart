// lib/features/admissions/admissions_service.dart

import 'package:dio/dio.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/dio_client.dart';

class AdmissionsService {
  final Dio _dio = DioClient.instance;

  Future<List<dynamic>> getLeads({String? stage, String? search}) async {
    final resp = await _dio.get(
      ApiConstants.admissions,
      queryParameters: {
        if (stage  != null) 'stage':  stage,
        if (search != null) 'search': search,
      },
    );
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createLead(Map<String, dynamic> data) async {
    final resp = await _dio.post(ApiConstants.admissions, data: data);
    return resp.data as Map<String, dynamic>;
  }

  /// Kanban pipeline counts by stage
  Future<List<dynamic>> getPipeline() async {
    final resp =
        await _dio.get('${ApiConstants.admissions}/pipeline');
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateLead(
      String id, Map<String, dynamic> data) async {
    final resp =
        await _dio.patch('${ApiConstants.admissions}/$id', data: data);
    return resp.data as Map<String, dynamic>;
  }

  /// Convert a lead into a full member
  Future<Map<String, dynamic>> convertLead(String id) async {
    final resp =
        await _dio.post('${ApiConstants.admissions}/$id/convert');
    return resp.data as Map<String, dynamic>;
  }
}

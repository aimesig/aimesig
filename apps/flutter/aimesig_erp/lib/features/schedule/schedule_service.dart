// lib/features/schedule/schedule_service.dart

import 'package:dio/dio.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/dio_client.dart';

class ScheduleService {
  final Dio _dio = DioClient.instance;

  Future<List<dynamic>> getSlots({
    String? batchId,
    String? staffId,
    String? date,
  }) async {
    final resp = await _dio.get(
      '${ApiConstants.schedule}/slots',
      queryParameters: {
        if (batchId != null) 'batch_id': batchId,
        if (staffId != null) 'staff_id': staffId,
        if (date    != null) 'date':     date,
      },
    );
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createSlot(
      Map<String, dynamic> data) async {
    final resp =
        await _dio.post('${ApiConstants.schedule}/slots', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSlot(
      String id, Map<String, dynamic> data) async {
    final resp = await _dio
        .patch('${ApiConstants.schedule}/slots/$id', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteSlot(String id) =>
      _dio.delete('${ApiConstants.schedule}/slots/$id');

  Future<Map<String, dynamic>> getConflicts() async {
    final resp =
        await _dio.get('${ApiConstants.schedule}/conflicts');
    return resp.data as Map<String, dynamic>;
  }
}

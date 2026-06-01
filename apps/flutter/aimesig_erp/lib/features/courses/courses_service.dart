// lib/features/courses/courses_service.dart

import 'package:dio/dio.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/dio_client.dart';

class CoursesService {
  final Dio _dio = DioClient.instance;

  // ── Courses ───────────────────────────────────────────────────────
  Future<List<dynamic>> getCourses() async {
    final resp = await _dio.get(ApiConstants.courses);
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCourse(Map<String, dynamic> data) async {
    final resp = await _dio.post(ApiConstants.courses, data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCourse(String id) async {
    final resp = await _dio.get('${ApiConstants.courses}/$id');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCourse(
      String id, Map<String, dynamic> data) async {
    final resp = await _dio.patch('${ApiConstants.courses}/$id', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteCourse(String id) =>
      _dio.delete('${ApiConstants.courses}/$id');

  Future<Map<String, dynamic>> publishCourse(String id) async {
    final resp = await _dio.post('${ApiConstants.courses}/$id/publish');
    return resp.data as Map<String, dynamic>;
  }

  // ── Batches ───────────────────────────────────────────────────────
  Future<List<dynamic>> getBatches(String courseId) async {
    final resp = await _dio.get('${ApiConstants.courses}/$courseId/batches');
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createBatch(
      String courseId, Map<String, dynamic> data) async {
    final resp = await _dio.post(
        '${ApiConstants.courses}/$courseId/batches', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBatch(
      String courseId, String batchId, Map<String, dynamic> data) async {
    final resp = await _dio.patch(
        '${ApiConstants.courses}/$courseId/batches/$batchId', data: data);
    return resp.data as Map<String, dynamic>;
  }

  // ── Members / Enrollments ─────────────────────────────────────────
  Future<List<dynamic>> getCourseMembers(String courseId) async {
    final resp = await _dio.get('${ApiConstants.courses}/$courseId/members');
    return resp.data as List<dynamic>;
  }

  /// Enroll a member into a specific batch of this course
  Future<Map<String, dynamic>> enrollMemberToCourse({
    required String courseId,
    required String memberId,
    required String batchId,
  }) async {
    final resp = await _dio.post(
      '${ApiConstants.courses}/$courseId/members',
      data: {'member_id': memberId, 'batch_id': batchId},
    );
    return resp.data as Map<String, dynamic>;
  }

  /// Remove (drop) a member from a course
  Future<void> removeMemberFromCourse(
      String courseId, String enrollmentId) async {
    await _dio.delete(
        '${ApiConstants.courses}/$courseId/members/$enrollmentId');
  }
}
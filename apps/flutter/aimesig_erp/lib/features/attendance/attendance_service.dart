// lib/features/attendance/attendance_service.dart

import 'package:dio/dio.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/dio_client.dart';

class AttendanceService {
  final Dio _dio = DioClient.instance;

  // ── Staff: get my assigned batches ───────────────────────────────
  Future<List<dynamic>> getMyBatches() async {
    final resp = await _dio.get('${ApiConstants.attendance}/my-batches');
    return resp.data as List<dynamic>;
  }

  // ── Get members of a batch for attendance marking ────────────────
  Future<List<dynamic>> getBatchMembers(String batchId, {String? date}) async {
    final resp = await _dio.get(
      '${ApiConstants.attendance}/batch/$batchId/members',
      queryParameters: {if (date != null) 'date': date},
    );
    return resp.data as List<dynamic>;
  }

  // ── Mark single attendance record ────────────────────────────────
  Future<Map<String, dynamic>> markAttendance({
    String?  memberId,
    String?  staffId,
    String?  slotId,
    String?  batchId,
    required String date,
    required String status, // present | absent | late
    String?  note,
  }) async {
    final resp = await _dio.post(
      '${ApiConstants.attendance}/mark',
      data: {
        if (memberId != null) 'member_id': memberId,
        if (staffId  != null) 'staff_id':  staffId,
        if (slotId   != null) 'slot_id':   slotId,
        if (batchId  != null) 'batch_id':  batchId,
        'date':   date,
        'status': status,
        if (note != null) 'note': note,
      },
    );
    return resp.data as Map<String, dynamic>;
  }

  // ── Bulk-mark full session ────────────────────────────────────────
  Future<Map<String, dynamic>> bulkMark({
    required String batchId,
    required String date,
    required List<Map<String, dynamic>> records,
    // records: [{ member_id, status, note? }]
  }) async {
    final resp = await _dio.post(
      '${ApiConstants.attendance}/bulk-mark',
      data: {'batch_id': batchId, 'date': date, 'records': records},
    );
    return resp.data as Map<String, dynamic>;
  }

  // ── Session attendance ────────────────────────────────────────────
  Future<List<dynamic>> getSessionAttendance(String slotId) async {
    final resp = await _dio.get('${ApiConstants.attendance}/session/$slotId');
    return resp.data as List<dynamic>;
  }

  // ── Member attendance history ─────────────────────────────────────
  Future<List<dynamic>> getMemberAttendance(
    String memberId, {
    String? from,
    String? to,
  }) async {
    final resp = await _dio.get(
      '${ApiConstants.attendance}/member/$memberId',
      queryParameters: {
        if (from != null) 'from': from,
        if (to   != null) 'to':   to,
      },
    );
    return resp.data as List<dynamic>;
  }

  // ── Report (aggregated by member) ────────────────────────────────
  Future<List<dynamic>> getAttendanceReport({
    String? batchId,
    String? from,
    String? to,
  }) async {
    final resp = await _dio.get(
      '${ApiConstants.attendance}/report',
      queryParameters: {
        if (batchId != null) 'batch_id': batchId,
        if (from    != null) 'from': from,
        if (to      != null) 'to':   to,
      },
    );
    return resp.data as List<dynamic>;
  }
}
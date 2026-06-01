// lib/features/finance/finance_service.dart

import 'package:dio/dio.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/dio_client.dart';

class FinanceService {
  final Dio _dio = DioClient.instance;

  // ── Fee Plans ────────────────────────────────────────────────────
  Future<List<dynamic>> getFeePlans() async {
    final resp = await _dio.get('${ApiConstants.finance}/fee-plans');
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createFeePlan(Map<String, dynamic> data) async {
    final resp =
        await _dio.post('${ApiConstants.finance}/fee-plans', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateFeePlan(
      String id, Map<String, dynamic> data) async {
    final resp =
        await _dio.patch('${ApiConstants.finance}/fee-plans/$id', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<void> deleteFeePlan(String id) =>
      _dio.delete('${ApiConstants.finance}/fee-plans/$id');

  // ── Invoices ─────────────────────────────────────────────────────
  Future<List<dynamic>> getInvoices({String? status, String? memberId}) async {
    final resp = await _dio.get(
      '${ApiConstants.finance}/invoices',
      queryParameters: {
        if (status   != null) 'status':    status,
        if (memberId != null) 'member_id': memberId,
      },
    );
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createInvoice(
      Map<String, dynamic> data) async {
    final resp =
        await _dio.post('${ApiConstants.finance}/invoices', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInvoice(String id) async {
    final resp = await _dio.get('${ApiConstants.finance}/invoices/$id');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendInvoice(String id) async {
    final resp =
        await _dio.post('${ApiConstants.finance}/invoices/$id/send');
    return resp.data as Map<String, dynamic>;
  }

  // ── Payments ─────────────────────────────────────────────────────
  Future<List<dynamic>> getPayments({
    String? memberId,
    String? from,
    String? to,
  }) async {
    final resp = await _dio.get(
      '${ApiConstants.finance}/payments',
      queryParameters: {
        if (memberId != null) 'member_id': memberId,
        if (from     != null) 'from': from,
        if (to       != null) 'to':   to,
      },
    );
    return resp.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> recordPayment(
      Map<String, dynamic> data) async {
    final resp =
        await _dio.post('${ApiConstants.finance}/payments', data: data);
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refundPayment(String id) async {
    final resp =
        await _dio.post('${ApiConstants.finance}/payments/$id/refund');
    return resp.data as Map<String, dynamic>;
  }

  // ── Reports ───────────────────────────────────────────────────────
  Future<List<dynamic>> getRevenueReport({String? from, String? to}) async {
    final resp = await _dio.get(
      '${ApiConstants.finance}/reports/revenue',
      queryParameters: {
        if (from != null) 'from': from,
        if (to   != null) 'to':   to,
      },
    );
    return resp.data as List<dynamic>;
  }

  Future<List<dynamic>> getOutstandingReport() async {
    final resp =
        await _dio.get('${ApiConstants.finance}/reports/outstanding');
    return resp.data as List<dynamic>;
  }
}

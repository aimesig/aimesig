// lib/core/api/api_constants.dart

class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.aimesig.com';

  // ERP Auth
  static const String login          = '/erp/auth/login';
  static const String register       = '/erp/auth/register';
  static const String refresh        = '/erp/auth/refresh';
  static const String forgotPassword = '/erp/auth/forgot-password';

  // ERP modules (all protected — JWT required)
  static const String members    = '/erp/members';
  static const String courses    = '/erp/courses';
  static const String admissions = '/erp/admissions';
  static const String attendance = '/erp/attendance';
  static const String finance    = '/erp/finance';
  static const String staff      = '/erp/staff';
  static const String schedule   = '/erp/schedule';
}

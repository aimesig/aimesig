import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';

class AuthService {
  final Dio dio = DioClient.dio;

  Future<Response> login({
    required String email,
    required String password,
  }) async {
    return await dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );
  }

  Future<Response> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return await dio.post(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
      },
    );
  }
}
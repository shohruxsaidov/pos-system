import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiService {
  late final Dio _dio;
  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  void setToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) async {
    return _dio.get(
      ApiConfig.endpoint(path),
      queryParameters: queryParams,
    );
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(ApiConfig.endpoint(path), data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return _dio.patch(ApiConfig.endpoint(path), data: data);
  }

  Future<bool> checkHealth() async {
    try {
      final res = await _dio.get(
        ApiConfig.endpoint('/health'),
        options: Options(sendTimeout: const Duration(seconds: 3)),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// Singleton
final apiService = ApiService();

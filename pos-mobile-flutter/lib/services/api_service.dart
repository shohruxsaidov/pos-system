import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/api_config.dart';

/// Thin wrapper so callers can use `.data` like they did with Dio.
class ApiResponse {
  final int statusCode;
  final dynamic data;

  ApiResponse(this.statusCode, this.data);
}

class ApiService {
  String? _token;
  final _client = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  void setToken(String? token) => _token = token;

  ApiResponse _parse(http.Response res) {
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    if (res.statusCode >= 400) {
      final message = body?['error'] ?? 'Request failed: ${res.statusCode}';
      if (res.statusCode >= 500) {
        Sentry.logger.fmt.error('API server error %d: %s', [res.statusCode, message]);
      } else {
        Sentry.logger.fmt.warning('API client error %d: %s', [res.statusCode, message]);
      }
      throw Exception(message);
    }
    return ApiResponse(res.statusCode, body);
  }

  Future<ApiResponse> get(String path,
      {Map<String, dynamic>? queryParams}) async {
    final uri = Uri.parse(ApiConfig.endpoint(path)).replace(
        queryParameters:
            queryParams?.map((k, v) => MapEntry(k, v.toString())));
    try {
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      return _parse(res);
    } catch (e, st) {
      if (e is! Exception || e.toString().startsWith('Exception: Request failed')) rethrow;
      Sentry.logger.fmt.error('GET %s failed: %s', [path, e]);
      await Sentry.captureException(e, stackTrace: st);
      rethrow;
    }
  }

  Future<ApiResponse> post(String path, {dynamic data}) async {
    final uri = Uri.parse(ApiConfig.endpoint(path));
    try {
      final res = await _client
          .post(uri,
              headers: _headers,
              body: data != null ? jsonEncode(data) : null)
          .timeout(const Duration(seconds: 10));
      return _parse(res);
    } catch (e, st) {
      if (e is! Exception || e.toString().startsWith('Exception: Request failed')) rethrow;
      Sentry.logger.fmt.error('POST %s failed: %s', [path, e]);
      await Sentry.captureException(e, stackTrace: st);
      rethrow;
    }
  }

  Future<ApiResponse> put(String path, {dynamic data}) async {
    final uri = Uri.parse(ApiConfig.endpoint(path));
    try {
      final res = await _client
          .put(uri,
              headers: _headers,
              body: data != null ? jsonEncode(data) : null)
          .timeout(const Duration(seconds: 10));
      return _parse(res);
    } catch (e, st) {
      if (e is! Exception || e.toString().startsWith('Exception: Request failed')) rethrow;
      Sentry.logger.fmt.error('PUT %s failed: %s', [path, e]);
      await Sentry.captureException(e, stackTrace: st);
      rethrow;
    }
  }

  Future<ApiResponse> patch(String path, {dynamic data}) async {
    final uri = Uri.parse(ApiConfig.endpoint(path));
    try {
      final res = await _client
          .patch(uri,
              headers: _headers,
              body: data != null ? jsonEncode(data) : null)
          .timeout(const Duration(seconds: 10));
      return _parse(res);
    } catch (e, st) {
      if (e is! Exception || e.toString().startsWith('Exception: Request failed')) rethrow;
      Sentry.logger.fmt.error('PATCH %s failed: %s', [path, e]);
      await Sentry.captureException(e, stackTrace: st);
      rethrow;
    }
  }

  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse(ApiConfig.endpoint('/health'));
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// Singleton
final apiService = ApiService();

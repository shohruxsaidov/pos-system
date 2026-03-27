import 'dart:convert';
import 'package:http/http.dart' as http;
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
      throw Exception(
          body?['error'] ?? 'Request failed: ${res.statusCode}');
    }
    return ApiResponse(res.statusCode, body);
  }

  Future<ApiResponse> get(String path,
      {Map<String, dynamic>? queryParams}) async {
    final uri = Uri.parse(ApiConfig.endpoint(path)).replace(
        queryParameters:
            queryParams?.map((k, v) => MapEntry(k, v.toString())));
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    return _parse(res);
  }

  Future<ApiResponse> post(String path, {dynamic data}) async {
    final uri = Uri.parse(ApiConfig.endpoint(path));
    final res = await _client
        .post(uri,
            headers: _headers,
            body: data != null ? jsonEncode(data) : null)
        .timeout(const Duration(seconds: 10));
    return _parse(res);
  }

  Future<ApiResponse> put(String path, {dynamic data}) async {
    final uri = Uri.parse(ApiConfig.endpoint(path));
    final res = await _client
        .put(uri,
            headers: _headers,
            body: data != null ? jsonEncode(data) : null)
        .timeout(const Duration(seconds: 10));
    return _parse(res);
  }

  Future<ApiResponse> patch(String path, {dynamic data}) async {
    final uri = Uri.parse(ApiConfig.endpoint(path));
    final res = await _client
        .patch(uri,
            headers: _headers,
            body: data != null ? jsonEncode(data) : null)
        .timeout(const Duration(seconds: 10));
    return _parse(res);
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

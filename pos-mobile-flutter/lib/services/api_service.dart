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

/// HTTP error returned by the backend. [toString] keeps the plain
/// `Exception: <message>` format callers strip for display.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'Exception: $message';
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
        Sentry.logger.fmt.error('API server error %s: %s', [res.statusCode, message]);
      } else {
        Sentry.logger.warn('API client error ${res.statusCode}: $message');
      }
      throw ApiException(res.statusCode, message.toString());
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
      // 4xx (e.g. 404 "Product not found" on barcode lookup) are expected
      // and handled by callers — don't report them as Sentry issues.
      if (e is! Exception || (e is ApiException && e.statusCode < 500)) rethrow;
      Sentry.logger.fmt.error('GET %s failed: %s', [path, e]);
      await Sentry.captureException(e, stackTrace: st);
      rethrow;
    }
  }

  /// [timeout] defaults to 10s; pass a longer one for slow endpoints such as
  /// /api/ai/chat, where Claude runs a multi-step tool loop server-side.
  Future<ApiResponse> post(String path,
      {dynamic data, Duration timeout = const Duration(seconds: 10)}) async {
    final uri = Uri.parse(ApiConfig.endpoint(path));
    try {
      final res = await _client
          .post(uri,
              headers: _headers,
              body: data != null ? jsonEncode(data) : null)
          .timeout(timeout);
      return _parse(res);
    } catch (e, st) {
      // 4xx (e.g. 404 "Product not found" on barcode lookup) are expected
      // and handled by callers — don't report them as Sentry issues.
      if (e is! Exception || (e is ApiException && e.statusCode < 500)) rethrow;
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
      // 4xx (e.g. 404 "Product not found" on barcode lookup) are expected
      // and handled by callers — don't report them as Sentry issues.
      if (e is! Exception || (e is ApiException && e.statusCode < 500)) rethrow;
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
      // 4xx (e.g. 404 "Product not found" on barcode lookup) are expected
      // and handled by callers — don't report them as Sentry issues.
      if (e is! Exception || (e is ApiException && e.statusCode < 500)) rethrow;
      Sentry.logger.fmt.error('PATCH %s failed: %s', [path, e]);
      await Sentry.captureException(e, stackTrace: st);
      rethrow;
    }
  }

  Future<ApiResponse> delete(String path, {dynamic data}) async {
    final uri = Uri.parse(ApiConfig.endpoint(path));
    try {
      final res = await _client
          .delete(uri,
              headers: _headers,
              body: data != null ? jsonEncode(data) : null)
          .timeout(const Duration(seconds: 10));
      return _parse(res);
    } catch (e, st) {
      // 4xx (e.g. 404 "Product not found" on barcode lookup) are expected
      // and handled by callers — don't report them as Sentry issues.
      if (e is! Exception || (e is ApiException && e.statusCode < 500)) rethrow;
      Sentry.logger.fmt.error('DELETE %s failed: %s', [path, e]);
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

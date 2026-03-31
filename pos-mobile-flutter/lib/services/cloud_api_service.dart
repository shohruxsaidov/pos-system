import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/cloud_config.dart';

class CloudApiService {
  final _client = http.Client();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (CloudConfig.token != null) 'Authorization': 'Bearer ${CloudConfig.token}',
  };

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    var uri = Uri.parse(CloudConfig.endpoint(path));
    if (queryParams != null) uri = uri.replace(queryParameters: queryParams);
    final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    return _parse(res);
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    final uri = Uri.parse(CloudConfig.endpoint(path));
    final res = await _client
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _parse(res);
  }

  dynamic _parse(http.Response res) {
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    if (res.statusCode >= 400) {
      final msg = body?['error'] ?? 'Request failed: ${res.statusCode}';
      throw Exception(msg);
    }
    return body;
  }
}

final cloudApiService = CloudApiService();

import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _baseUrlKey = 'api_base_url';
  static const String defaultBaseUrl = 'http://192.168.1.100:3000';

  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
  }

  static Future<void> save(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }

  static String endpoint(String path) => '$_baseUrl$path';
}

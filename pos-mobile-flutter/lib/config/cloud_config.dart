import 'package:shared_preferences/shared_preferences.dart';

class CloudConfig {
  static const _urlKey   = 'cloud_url';
  static const _tokenKey = 'cloud_token';

  static String? _url;
  static String? _token;

  static String? get url   => _url;
  static String? get token => _token;
  static bool get isConfigured => _url != null && _token != null;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _url   = prefs.getString(_urlKey);
    _token = prefs.getString(_tokenKey);
  }

  static Future<void> save({ required String url, required String token }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url.trimRight().replaceAll(RegExp(r'/$'), ''));
    await prefs.setString(_tokenKey, token);
    _url   = url.trimRight().replaceAll(RegExp(r'/$'), '');
    _token = token;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_tokenKey);
    _url   = null;
    _token = null;
  }

  static String endpoint(String path) => '${_url ?? ''}$path';
}

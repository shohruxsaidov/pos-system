import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _productsCacheKey = 'pos_products_cache';
const _cacheTimestampKey = 'pos_products_cache_ts';
const _cacheTtlHours = 8;

Future<void> saveProductsCache(List<Map<String, dynamic>> products) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_productsCacheKey, jsonEncode(products));
  await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
}

Future<List<Map<String, dynamic>>?> loadProductsCache() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_productsCacheKey);
  final ts = prefs.getInt(_cacheTimestampKey) ?? 0;
  if (raw == null) return null;
  final age = DateTime.now().millisecondsSinceEpoch - ts;
  if (age > _cacheTtlHours * 3600 * 1000) return null;
  return List<Map<String, dynamic>>.from(jsonDecode(raw));
}

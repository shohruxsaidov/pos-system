import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

const _queueKey = 'pos_sale_queue';
const _productsCacheKey = 'pos_products_cache';
const _cacheTimestampKey = 'pos_products_cache_ts';
const _cacheTtlHours = 8;

String generateClientRef() {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final rand = Random().nextInt(99999).toString().padLeft(5, '0');
  return 'OFFLINE-$ts-$rand';
}

Future<List<Map<String, dynamic>>> getQueue() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_queueKey);
  if (raw == null) return [];
  return List<Map<String, dynamic>>.from(jsonDecode(raw));
}

Future<void> enqueue(Map<String, dynamic> sale) async {
  final prefs = await SharedPreferences.getInstance();
  final queue = await getQueue();
  queue.add(sale);
  await prefs.setString(_queueKey, jsonEncode(queue));
}

Future<Map<String, dynamic>?> dequeue() async {
  final prefs = await SharedPreferences.getInstance();
  final queue = await getQueue();
  if (queue.isEmpty) return null;
  final item = queue.removeAt(0);
  await prefs.setString(_queueKey, jsonEncode(queue));
  return item;
}

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

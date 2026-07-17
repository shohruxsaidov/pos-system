import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/offline_draft.dart';
import '../models/product.dart';

const _productsCacheKey = 'pos_products_cache';
const _cacheTimestampKey = 'pos_products_cache_ts';

const _draftsKey = 'pos_offline_drafts';

// ─── Product cache ────────────────────────────────────────────────────────────
//
// The full product catalog is persisted so it stays fully searchable offline.
// The cache never expires: an old catalog is far more useful than an empty one
// when there is no connection. The timestamp is kept only for freshness display.

Future<void> saveProductsCache(List<Map<String, dynamic>> products) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_productsCacheKey, jsonEncode(products));
  await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
}

Future<List<Map<String, dynamic>>?> loadProductsCache() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_productsCacheKey);
  if (raw == null) return null;
  return List<Map<String, dynamic>>.from(jsonDecode(raw));
}

/// Millis-epoch of the last successful catalog cache write, or null if never.
Future<int?> productsCacheTimestamp() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_cacheTimestampKey);
}

Future<Product?> resolveProductByBarcode(String barcode) async {
  final cached = await loadProductsCache();
  if (cached == null) return null;
  final match = cached.cast<Map<String, dynamic>?>().firstWhere(
        (p) => _matchesBarcode(p!, barcode),
        orElse: () => null,
      );
  if (match == null) return null;
  return Product.fromJson(match);
}

/// True if [product] carries [barcode] as its primary code or in its
/// alternate `barcodes[]` list (mirrors the server's multi-barcode lookup).
bool _matchesBarcode(Map<String, dynamic> product, String barcode) {
  if (product['barcode'] == barcode) return true;
  final alts = product['barcodes'];
  if (alts is List) {
    return alts.any((b) => b is Map && b['barcode'] == barcode);
  }
  return false;
}

// ─── Reports cache ────────────────────────────────────────────────────────────

const _reportsCachePrefix = 'pos_reports_cache_';
const _reportsCacheTsPrefix = 'pos_reports_cache_ts_';
const _reportsCacheTtlMinutes = 60;

Future<void> saveReportsCache(
    String date, Map<String, dynamic> payload) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('$_reportsCachePrefix$date', jsonEncode(payload));
  await prefs.setInt('$_reportsCacheTsPrefix$date',
      DateTime.now().millisecondsSinceEpoch);
}

/// Returns cached payload with extra key `cachedAt` (ms epoch), or null if
/// no cache / stale (> 60 min).
Future<Map<String, dynamic>?> loadReportsCache(String date) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('$_reportsCachePrefix$date');
  final ts = prefs.getInt('$_reportsCacheTsPrefix$date') ?? 0;
  if (raw == null) return null;
  final age = DateTime.now().millisecondsSinceEpoch - ts;
  if (age > _reportsCacheTtlMinutes * 60 * 1000) return null;
  return {
    ...jsonDecode(raw) as Map<String, dynamic>,
    'cachedAt': ts,
  };
}

// ─── Offline drafts ───────────────────────────────────────────────────────────

Future<List<OfflineDraft>> loadDrafts() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_draftsKey);
  if (raw == null) return [];
  final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
  return list
      .map((e) => OfflineDraft.fromJson(e))
      .where((d) => d.status != OfflineDraftStatus.synced)
      .toList();
}

Future<void> saveDrafts(List<OfflineDraft> drafts) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_draftsKey, jsonEncode(drafts.map((d) => d.toJson()).toList()));
}

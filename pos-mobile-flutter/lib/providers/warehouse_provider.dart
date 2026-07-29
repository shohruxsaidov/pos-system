import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../services/offline_queue_service.dart';

class WarehouseState {
  final List<Product> products;
  final List<Category> categories;
  final bool loading;

  const WarehouseState({
    this.products = const [],
    this.categories = const [],
    this.loading = false,
  });

  WarehouseState copyWith({
    List<Product>? products,
    List<Category>? categories,
    bool? loading,
  }) =>
      WarehouseState(
        products: products ?? this.products,
        categories: categories ?? this.categories,
        loading: loading ?? this.loading,
      );
}

class WarehouseNotifier extends Notifier<WarehouseState> {
  @override
  WarehouseState build() => const WarehouseState();

  Future<void> fetchProducts() async {
    // Hydrate instantly from the offline cache on a cold start so the catalog
    // is searchable immediately — even offline, without waiting for the network
    // request to time out. A successful fetch below overwrites it with fresh data.
    if (state.products.isEmpty) {
      final cached = await loadProductsCache();
      if (cached != null && cached.isNotEmpty) {
        state = state.copyWith(
          products: cached.map((e) => Product.fromJson(e)).toList(),
        );
      }
    }
    state = state.copyWith(loading: true);
    try {
      final res = await apiService.get('/api/inventory/mobile');
      final products = (res.data as List)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
      await saveProductsCache(products.map((p) => p.toJson()).toList());
      state = state.copyWith(products: products, loading: false);
      Sentry.logger.fmt.info('Products fetched from server: %s items', [products.length]);
    } catch (e) {
      // Fallback to cache
      Sentry.logger.warn('Product fetch failed, falling back to cache: $e');
      Sentry.metrics.count('products.cache_fallback', 1);
      final cached = await loadProductsCache();
      if (cached != null) {
        final products = cached.map((e) => Product.fromJson(e)).toList();
        state = state.copyWith(products: products, loading: false);
        Sentry.logger.fmt.info('Loaded %d products from cache', [products.length]);
      } else {
        Sentry.logger.error('Product fetch failed and no cache available');
        Sentry.metrics.count('products.cache_miss', 1);
        state = state.copyWith(loading: false);
      }
    }
  }

  /// Re-persist the current in-memory catalog to the offline cache so local
  /// edits (price, barcodes, stock, deletes) survive for offline search.
  Future<void> _persistCache() async {
    await saveProductsCache(state.products.map((p) => p.toJson()).toList());
  }

  Future<Map<String, dynamic>> submitSale(Map<String, dynamic> payload) async {
    try {
      final res = await apiService.post('/api/transactions', data: payload);
      await _deductStockLocally(payload);
      final txn = res.data as Map<String, dynamic>;
      final total = (payload['total'] as num).toDouble();
      final itemCount = (payload['items'] as List).length;
      Sentry.logger.fmt.info('Sale submitted: ref=%s total=%s', [txn['ref_no'] ?? '-', total]);
      Sentry.metrics.count('sales.completed', 1);
      Sentry.metrics.distribution('sales.amount', total);
      Sentry.metrics.distribution('sales.items_per_transaction', itemCount.toDouble());
      return txn;
    } catch (e, st) {
      Sentry.logger.fmt.error('Sale submission failed: %s', [e]);
      await Sentry.captureException(e, stackTrace: st);
      Sentry.metrics.count('sales.failed', 1);
      rethrow;
    }
  }

  Future<void> fetchCategories() async {
    try {
      final res = await apiService.get('/api/categories');
      final categories = (res.data as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(categories: categories);
    } catch (e) {
      Sentry.logger.warn('Category fetch failed: $e');
    }
  }

  Future<void> editProduct(
    int id, {
    required String name,
    required String unit,
    int? categoryId,
    String? categoryName,
    int sortOrder = 0,
  }) async {
    await apiService.put('/api/products/$id', data: {
      'name': name,
      'unit': unit,
      'category_id': ?categoryId,
      'sort_order': sortOrder,
    });
    final updated = state.products.map((p) {
      if (p.id == id) {
        return p.copyWith(
          name: name,
          unit: unit,
          categoryId: categoryId,
          categoryName: categoryName,
          sortOrder: sortOrder,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(products: updated);
    await _persistCache();
  }

  Future<void> updatePrice(int id, double price) async {
    await apiService.put('/api/products/$id', data: {'price': price});
    final updated = state.products.map((p) {
      if (p.id == id) return p.copyWith(price: price);
      return p;
    }).toList();
    state = state.copyWith(products: updated);
    await _persistCache();
  }

  Future<void> updateBarcodes(int id, List<Map<String, dynamic>> barcodes) async {
    await apiService.put('/api/products/$id', data: {'barcodes': barcodes});
    final primary = barcodes.firstWhere(
      (b) => b['is_primary'] == 1 || b['is_primary'] == true,
      orElse: () => barcodes.isNotEmpty ? barcodes.first : <String, dynamic>{},
    );
    final primaryBarcode = primary.isNotEmpty ? primary['barcode'] as String? : null;
    final updated = state.products.map((p) {
      if (p.id == id) return p.copyWith(barcode: primaryBarcode, barcodes: barcodes);
      return p;
    }).toList();
    state = state.copyWith(products: updated);
    await _persistCache();
  }

  Future<void> deleteProduct(int id) async {
    await apiService.delete('/api/products/$id');
    final updated = state.products.where((p) => p.id != id).toList();
    state = state.copyWith(products: updated);
    await _persistCache();
    Sentry.logger.fmt.info('Product deleted: id=%s', [id]);
  }

  Future<String> generateBarcode(int id) async {
    final res = await apiService.get(
      '/api/barcode/generate',
      queryParams: {'product_id': id},
    );
    final data = res.data as Map<String, dynamic>;
    return data['barcode'] as String;
  }

  Future<void> updateStockLocally(int id, double delta) async {
    final updated = state.products.map((p) {
      if (p.id == id) return p.copyWith(stockQty: p.stockQty + delta);
      return p;
    }).toList();
    state = state.copyWith(products: updated);
    await _persistCache();
  }

  Future<void> _deductStockLocally(Map<String, dynamic> payload) async {
    final items = payload['items'] as List?;
    if (items == null) return;
    final updated = state.products.map((p) {
      final item = items.cast<Map<String, dynamic>?>().firstWhere(
        (i) => i!['product_id'] == p.id,
        orElse: () => null,
      );
      if (item == null) return p;
      final qty = (item['qty'] as num).toDouble();
      return p.copyWith(stockQty: p.stockQty - qty);
    }).toList();
    state = state.copyWith(products: updated);
    await _persistCache();
  }
}

final warehouseProvider =
    NotifierProvider<WarehouseNotifier, WarehouseState>(WarehouseNotifier.new);

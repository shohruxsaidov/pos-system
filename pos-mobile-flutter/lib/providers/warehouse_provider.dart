import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/offline_queue_service.dart';

class WarehouseState {
  final List<Product> products;
  final bool loading;

  const WarehouseState({
    this.products = const [],
    this.loading = false,
  });

  WarehouseState copyWith({
    List<Product>? products,
    bool? loading,
  }) =>
      WarehouseState(
        products: products ?? this.products,
        loading: loading ?? this.loading,
      );
}

class WarehouseNotifier extends Notifier<WarehouseState> {
  @override
  WarehouseState build() => const WarehouseState();

  Future<void> fetchProducts() async {
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

  Future<Map<String, dynamic>> submitSale(Map<String, dynamic> payload) async {
    try {
      final res = await apiService.post('/api/transactions', data: payload);
      _deductStockLocally(payload);
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

  Future<void> renameProduct(int id, String name) async {
    await apiService.put('/api/products/$id', data: {'name': name});
    final updated = state.products.map((p) {
      if (p.id == id) return p.copyWith(name: name);
      return p;
    }).toList();
    state = state.copyWith(products: updated);
  }

  Future<void> updatePrice(int id, double price) async {
    await apiService.put('/api/products/$id', data: {'price': price});
    final updated = state.products.map((p) {
      if (p.id == id) return p.copyWith(price: price);
      return p;
    }).toList();
    state = state.copyWith(products: updated);
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
  }

  Future<String> generateBarcode(int id) async {
    final res = await apiService.get(
      '/api/barcode/generate',
      queryParams: {'product_id': id},
    );
    final data = res.data as Map<String, dynamic>;
    return data['barcode'] as String;
  }

  void updateStockLocally(int id, double delta) {
    final updated = state.products.map((p) {
      if (p.id == id) return p.copyWith(stockQty: p.stockQty + delta);
      return p;
    }).toList();
    state = state.copyWith(products: updated);
  }

  void _deductStockLocally(Map<String, dynamic> payload) {
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
  }
}

final warehouseProvider =
    NotifierProvider<WarehouseNotifier, WarehouseState>(WarehouseNotifier.new);

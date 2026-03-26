import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/offline_queue_service.dart';

class WarehouseState {
  final List<Product> products;
  final bool loading;
  final int queueLength;
  final bool isSyncing;

  const WarehouseState({
    this.products = const [],
    this.loading = false,
    this.queueLength = 0,
    this.isSyncing = false,
  });

  WarehouseState copyWith({
    List<Product>? products,
    bool? loading,
    int? queueLength,
    bool? isSyncing,
  }) =>
      WarehouseState(
        products: products ?? this.products,
        loading: loading ?? this.loading,
        queueLength: queueLength ?? this.queueLength,
        isSyncing: isSyncing ?? this.isSyncing,
      );
}

class WarehouseNotifier extends StateNotifier<WarehouseState> {
  Timer? _syncTimer;

  WarehouseNotifier() : super(const WarehouseState()) {
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => syncQueue());
  }

  Future<void> fetchProducts() async {
    state = state.copyWith(loading: true);
    try {
      final res = await apiService.get('/api/inventory/mobile');
      final products = (res.data as List)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
      await saveProductsCache(
          products.map((p) => p.toJson()).toList());
      final queue = await getQueue();
      state = state.copyWith(
          products: products, loading: false, queueLength: queue.length);
    } catch (_) {
      // Fallback to cache
      final cached = await loadProductsCache();
      if (cached != null) {
        final products =
            cached.map((e) => Product.fromJson(e)).toList();
        state = state.copyWith(products: products, loading: false);
      } else {
        state = state.copyWith(loading: false);
      }
    }
  }

  Future<Map<String, dynamic>> submitSale(Map<String, dynamic> payload) async {
    final isOnline = await apiService.checkHealth();
    if (!isOnline) {
      final sale = Map<String, dynamic>.from(payload);
      sale['client_ref'] = generateClientRef();
      await enqueue(sale);
      final queue = await getQueue();
      state = state.copyWith(queueLength: queue.length);
      _deductStockLocally(payload);
      return {'queued': true, 'client_ref': sale['client_ref']};
    }
    final res = await apiService.post('/api/transactions', data: payload);
    _deductStockLocally(payload);
    return res.data as Map<String, dynamic>;
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
      final qty = (item['qty'] as num).toInt();
      return p.copyWith(stockQty: p.stockQty - qty);
    }).toList();
    state = state.copyWith(products: updated);
  }

  Future<void> syncQueue() async {
    final queue = await getQueue();
    if (queue.isEmpty) return;
    final isOnline = await apiService.checkHealth();
    if (!isOnline) return;

    state = state.copyWith(isSyncing: true);
    while (true) {
      final item = await dequeue();
      if (item == null) break;
      try {
        await apiService.post('/api/transactions', data: item);
      } catch (_) {
        await enqueue(item);
        break;
      }
    }
    final remaining = await getQueue();
    state = state.copyWith(
        isSyncing: false, queueLength: remaining.length);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

final warehouseProvider =
    StateNotifierProvider<WarehouseNotifier, WarehouseState>(
  (ref) => WarehouseNotifier(),
);

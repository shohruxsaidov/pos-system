import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/product.dart';
import '../providers/warehouse_provider.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';
import '../widgets/stock_adjust_sheet.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all'; // all | low | oversold

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(warehouseProvider.notifier).fetchProducts();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _filtered(List<Product> products) {
    var list = products;
    if (_filter == 'low') {
      list = list.where((p) => p.stockQty > 0 && p.stockQty <= 5).toList();
    } else if (_filter == 'oversold') {
      list = list.where((p) => p.stockQty < 0).toList()
        ..sort((a, b) => a.stockQty.compareTo(b.stockQty));
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              (p.barcode?.contains(q) ?? false))
          .toList();
    }
    return list;
  }

  void _openAdjust(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StockAdjustSheet(
        product: product,
        onDone: () {
          Navigator.pop(context);
          ref.read(warehouseProvider.notifier).fetchProducts();
        },
      ),
    );
  }

  String _formatCompact(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(2);
  }

  Future<void> _printLabel(Product product) async {
    try {
      await apiService.post('/api/barcode/print', data: {
        'product_id': product.id,
        'barcode': product.barcode,
        'name': product.name,
        'price': product.price,
        'source': 'mobile',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Отправлено на печать'),
            backgroundColor: AppColors.successBg,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка печати — десктоп не подключён'),
            backgroundColor: AppColors.dangerBg,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(warehouseProvider);
    final filtered = _filtered(state.products);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Поиск товаров...',
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.textMuted),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppColors.textMuted),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Filter tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  _FilterTab(
                      label: 'Все',
                      count: state.products.length,
                      active: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all')),
                  const SizedBox(width: 8),
                  _FilterTab(
                      label: 'Мало',
                      count: state.products
                          .where((p) => p.stockQty > 0 && p.stockQty <= 5)
                          .length,
                      active: _filter == 'low',
                      color: AppColors.warning,
                      onTap: () => setState(() => _filter = 'low')),
                  const SizedBox(width: 8),
                  _FilterTab(
                      label: 'Дефицит',
                      count:
                          state.products.where((p) => p.stockQty < 0).length,
                      active: _filter == 'oversold',
                      color: AppColors.danger,
                      onTap: () => setState(() => _filter = 'oversold')),
                ],
              ),
            ),

            // Stats bar
            if (!state.loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${filtered.length}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const Text('Товаров',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 32,
                          color: AppColors.borderDefault),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCompact(filtered.fold<double>(
                                  0,
                                  (s, p) =>
                                      s + p.price * p.stockQty)),
                              style: const TextStyle(
                                color: AppColors.textAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const Text('Общая стоимость',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Product list
            Expanded(
              child: state.loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent1))
                  : filtered.isEmpty
                      ? const Center(
                          child: Text('Нет товаров',
                              style:
                                  TextStyle(color: AppColors.textMuted)))
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(12, 4, 12, 20),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ProductCard(
                              product: filtered[i],
                              onAdjust: () => _openAdjust(filtered[i]),
                              onPrint: () => _printLabel(filtered[i]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.count,
    required this.active,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent1;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.15) : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? c : AppColors.borderDefault),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: active ? c : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: active ? c.withOpacity(0.2) : AppColors.bgInput,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                    color: active ? c : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

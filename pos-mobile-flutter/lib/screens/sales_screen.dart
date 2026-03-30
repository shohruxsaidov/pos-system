import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/app_theme.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/connectivity_provider.dart';
import '../providers/warehouse_provider.dart';
import '../utils/format.dart';
import '../services/api_service.dart';
import '../widgets/cart_sheet.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/sale_product_card.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  final List<CartItem> _cart = [];
  bool _cartOpen = false;
  bool _paymentOpen = false;

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
    _searchFocus.dispose();
    super.dispose();
  }

  List<Product> _filtered(List<Product> products) {
    if (_query.isEmpty) return products;
    final q = _query.toLowerCase();
    return products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.barcode?.contains(q) ?? false))
        .toList();
  }

  void _onSearch(String val) {
    setState(() => _query = val);
  }

  Future<void> _onBarcodeSubmit() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    try {
      final res = await apiService.get('/api/products/barcode/$q');
      final product = Product.fromJson(res.data as Map<String, dynamic>);
      _addToCart(product);
      _searchCtrl.clear();
      setState(() => _query = '');
    } catch (_) {
      // fallback: filter by name
    }
  }

  void _addToCart(Product product) {
    final existing = _cart.indexWhere((c) => c.product.id == product.id);
    setState(() {
      if (existing >= 0) {
        _cart[existing].qty += 1;
      } else {
        _cart.add(CartItem(
            product: product, qty: 1, unitPrice: product.price));
      }
    });
  }

  void _removeFromCart(CartItem item) {
    setState(() => _cart.remove(item));
  }

  void _updateQty(CartItem item, double newQty) {
    setState(() {
      final i = _cart.indexOf(item);
      if (i >= 0) _cart[i] = item.copyWith(qty: newQty);
    });
  }

  double get _cartTotal =>
      _cart.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> _processPayment({
    required String method,
    required double tendered,
    required double discount,
  }) async {
    final net = (_cartTotal - discount).clamp(0, double.infinity);
    final payload = {
      'items': _cart
          .map((c) => {
                'product_id': c.product.id,
                'qty': c.qty,
                'unit_price': c.unitPrice,
                'discount': 0,
                'subtotal': c.subtotal,
              })
          .toList(),
      'subtotal': _cartTotal,
      'discount': discount,
      'tax': 0,
      'total': net,
      'payment_method': method,
      'tendered': tendered,
    };

    Sentry.logger.fmt.info('Payment initiated: method=%s items=%s total=%s', [method, _cart.length, net]);
    try {
      await ref.read(warehouseProvider.notifier).submitSale(payload);
      setState(() {
        _cart.clear();
        _paymentOpen = false;
        _cartOpen = false;
      });
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       content: Text('Sale completed!'),
      //       backgroundColor: AppColors.successBg,
      //       behavior: SnackBarBehavior.floating,
      //       margin: EdgeInsets.all(16),
      //     ),
      //   );
      // }
    } catch (e, st) {
      Sentry.logger.fmt.error('Payment failed: method=%s total=%s error=%s', [method, net, e]);
      await Sentry.captureException(e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.dangerBg,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(warehouseProvider);
    final isOnline = ref.watch(connectivityProvider);
    final filtered = _filtered(state.products);
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: _onSearch,
                    onSubmitted: (_) => _onBarcodeSubmit(),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Сканировать или поиск...',
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textMuted),
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

                // Products grid
                Expanded(
                  child: state.loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent1))
                      : filtered.isEmpty
                          ? const Center(
                              child: Text('Товары не найдены',
                                  style: TextStyle(
                                      color: AppColors.textMuted)))
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  12, 0, 12, 100),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                mainAxisExtent: 130,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final p = filtered[i];
                                final cqty = _cart
                                    .where((c) => c.product.id == p.id)
                                    .fold<int>(
                                        0,
                                        (s, c) =>
                                            s + c.qty.toInt());
                                return SaleProductCard(
                                  product: p,
                                  cartQty: cqty,
                                  query: _query,
                                  onTap: () => _addToCart(p),
                                );
                              },
                            ),
                ),
              ],
            ),

            // Cart FAB
            if (_cart.isNotEmpty && !_cartOpen && !_paymentOpen)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () {
                    if (!isOnline) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Офлайн — используйте черновики'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    setState(() => _cartOpen = true);
                  },
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientHero,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.hero2.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_cart.length}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text('Корзина',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Text(
                            formatPrice(_cartTotal),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Cart Sheet
            if (_cartOpen)
              _BottomSheetOverlay(
                onClose: () => setState(() => _cartOpen = false),
                child: CartSheet(
                  items: _cart,
                  onUpdateQty: _updateQty,
                  onRemove: _removeFromCart,
                  onCheckout: () => setState(() {
                    _cartOpen = false;
                    _paymentOpen = true;
                  }),
                  onClose: () => setState(() => _cartOpen = false),
                ),
              ),

            // Payment Sheet
            if (_paymentOpen)
              _BottomSheetOverlay(
                onClose: () => setState(() => _paymentOpen = false),
                child: PaymentSheet(
                  total: _cartTotal,
                  onConfirm: ({required method, required tendered, required discount}) {
                    _processPayment(
                        method: method,
                        tendered: tendered,
                        discount: discount);
                  },
                  onClose: () => setState(() => _paymentOpen = false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetOverlay extends StatelessWidget {
  final Widget child;
  final VoidCallback onClose;

  const _BottomSheetOverlay({required this.child, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // prevent close on child tap
            child: child,
          ),
        ),
      ),
    );
  }
}

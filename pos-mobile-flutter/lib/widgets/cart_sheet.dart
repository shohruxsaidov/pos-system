import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../models/cart_item.dart';
import 'bottom_numpad.dart';

/// CartSheet — equivalent to CartSheet.vue
class CartSheet extends StatefulWidget {
  final List<CartItem> items;
  final void Function(CartItem item, double newQty) onUpdateQty;
  final void Function(CartItem item) onRemove;
  final VoidCallback onCheckout;
  final VoidCallback onClose;

  const CartSheet({
    super.key,
    required this.items,
    required this.onUpdateQty,
    required this.onRemove,
    required this.onCheckout,
    required this.onClose,
  });

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  final _fmt = NumberFormat('#,##0.00');

  double get _total =>
      widget.items.fold(0, (sum, item) => sum + item.subtotal);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: AppColors.borderDefault,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Text('Корзина',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentGlow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.items.length} поз.',
                    style: const TextStyle(
                        color: AppColors.accent1, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Items
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: widget.items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
              itemBuilder: (_, i) => _CartItemRow(
                item: widget.items[i],
                onQtyTap: () => _editQty(context, widget.items[i]),
                onRemove: () => widget.onRemove(widget.items[i]),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // Total + Checkout
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).viewPadding.bottom + 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Итого',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16)),
                    Text(
                      _fmt.format(_total),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GradientButton(
                  height: 56,
                  onTap: widget.onCheckout,
                  child: const Text(
                    'Оформить',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editQty(BuildContext context, CartItem item) async {
    final result = await BottomNumPad.show(
      context,
      title: 'Количество: ${item.product.name}',
      initialValue: item.qty.toString(),
      allowDecimal: true,
    );
    if (result != null && result.isNotEmpty) {
      final newQty = double.tryParse(result);
      if (newQty != null && newQty > 0) {
        widget.onUpdateQty(item, newQty);
      }
    }
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final VoidCallback onQtyTap;
  final VoidCallback onRemove;

  const _CartItemRow({
    required this.item,
    required this.onQtyTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '${fmt.format(item.unitPrice)} × ${item.qty}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          // Qty control
          GestureDetector(
            onTap: onQtyTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Text(
                item.qty % 1 == 0
                    ? item.qty.toInt().toString()
                    : item.qty.toStringAsFixed(2),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(fmt.format(item.subtotal),
              style: const TextStyle(
                  color: AppColors.textAccent,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.danger, size: 20),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

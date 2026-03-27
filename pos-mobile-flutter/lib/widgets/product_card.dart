import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../models/product.dart';
import '../utils/stock_status.dart';

/// MobileProductCard — equivalent to MobileProductCard.vue
class ProductCard extends StatelessWidget {
  final Product product;
  final int? cartQty;
  final VoidCallback? onAdjust;
  final VoidCallback? onPrint;
  final VoidCallback? onRename;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.cartQty,
    this.onAdjust,
    this.onPrint,
    this.onRename,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.gradientCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + cart badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (cartQty != null && cartQty! > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentGlow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$cartQty',
                      style: const TextStyle(
                          color: AppColors.accent1,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),

            // Barcode
            if (product.barcode != null)
              Text(
                product.barcode!,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),

            // Category
            if (product.categoryName != null) ...[
              const SizedBox(height: 2),
              Text(
                product.categoryName!,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 8),

            // Price + stock
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    fmt.format(product.price),
                    style: const TextStyle(
                      color: AppColors.textAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StockBadge(qty: product.stockQty),
                    if (product.unit.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Text(
                          product.unit,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            // Action buttons
            if (onAdjust != null || onPrint != null || onRename != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onAdjust != null)
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.tune,
                        label: 'Коррекция',
                        color: AppColors.warning,
                        onTap: onAdjust!,
                      ),
                    ),
                  if (onAdjust != null && onRename != null)
                    const SizedBox(width: 6),
                  if (onRename != null)
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.edit_outlined,
                        label: 'Переименовать',
                        color: AppColors.accent1,
                        onTap: onRename!,
                      ),
                    ),
                  if ((onAdjust != null || onRename != null) && onPrint != null)
                    const SizedBox(width: 6),
                  if (onPrint != null)
                    _ActionBtn(
                      icon: Icons.print_outlined,
                      label: '',
                      color: AppColors.textSecondary,
                      onTap: onPrint!,
                      compact: true,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
            : const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(icon, color: color, size: 14),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }
}

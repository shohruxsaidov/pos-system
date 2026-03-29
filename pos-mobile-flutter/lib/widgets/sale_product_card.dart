import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../models/product.dart';
import '../utils/stock_status.dart';
import 'highlight_text.dart';

/// Compact sale card — matches MobileSaleView.vue product grid card
class SaleProductCard extends StatelessWidget {
  final Product product;
  final int cartQty;
  final String query;
  final VoidCallback onTap;

  const SaleProductCard({
    super.key,
    required this.product,
    required this.cartQty,
    this.query = '',
    required this.onTap,
  });

  String _stockLabel(double qty) {
    if (qty < 0) return '−${qty.abs()}';
    if (qty == 0) return 'Нет';
    if (qty <= 5) return 'Мало: $qty';
    return '$qty шт';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final status = StockStatus.from(product.stockQty);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: AppColors.accent1.withValues(alpha: 0.12),
            highlightColor: AppColors.bgHover.withValues(alpha: 0.6),
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name — 2 lines max
                  HighlightText(
                    text: product.name,
                    query: query,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Price — gradient hero text
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppColors.gradientHero.createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: Text(
                      fmt.format(product.price),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: Colors.white, // overridden by ShaderMask
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Footer: stock badge + add icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Stock badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: status.bgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _stockLabel(product.stockQty),
                          style: TextStyle(
                            color: status.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Add "+" icon
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.accent1.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            '+',
                            style: TextStyle(
                              color: AppColors.accent1,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // In-cart badge (top-right corner)
        if (cartQty > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                gradient: AppColors.gradientHero,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.hero2.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$cartQty',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

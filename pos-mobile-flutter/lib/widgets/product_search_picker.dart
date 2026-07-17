import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/product.dart';
import '../utils/format.dart';
import '../utils/stock_status.dart';

/// Bottom-sheet list of catalog products matching a name/barcode query,
/// shown when a scan/search submit finds no exact barcode. Tapping a row
/// pops the sheet with that product so the caller can act on it.
///
/// Show it via [show], which auto-selects when there is a single match and
/// returns null when there are none.
class ProductSearchPicker extends StatelessWidget {
  final String query;
  final List<Product> matches;

  const ProductSearchPicker({
    super.key,
    required this.query,
    required this.matches,
  });

  /// Resolve one product for [query] from [matches]: null when empty, the
  /// sole match when there is one, otherwise whatever the user taps in the
  /// picker sheet (or null if dismissed).
  static Future<Product?> show(
    BuildContext context, {
    required String query,
    required List<Product> matches,
  }) {
    if (matches.isEmpty) return Future.value(null);
    if (matches.length == 1) return Future.value(matches.first);
    return showModalBottomSheet<Product>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProductSearchPicker(query: query, matches: matches),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Найдено: ${matches.length}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '"$query"',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                shrinkWrap: true,
                itemCount: matches.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = matches[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).pop(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
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
                                  p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                StockBadge(qty: p.stockQty),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatPrice(p.price),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

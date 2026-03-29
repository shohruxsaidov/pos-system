import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class StockStatus {
  final String label;
  final Color color;
  final Color bgColor;

  const StockStatus({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  static StockStatus from(double qty) {
    if (qty < 0) {
      return StockStatus(
        label: 'Дефицит ($qty)',
        color: AppColors.danger,
        bgColor: AppColors.dangerBg,
      );
    }
    if (qty == 0) {
      return StockStatus(
        label: 'Нет в наличии',
        color: AppColors.danger,
        bgColor: AppColors.dangerBg,
      );
    }
    if (qty <= 5) {
      return StockStatus(
        label: 'Мало ($qty)',
        color: AppColors.warning,
        bgColor: AppColors.warningBg,
      );
    }
    return StockStatus(
      label: '$qty на складе',
      color: AppColors.success,
      bgColor: AppColors.successBg,
    );
  }
}

class StockBadge extends StatelessWidget {
  final double qty;

  const StockBadge({super.key, required this.qty});

  @override
  Widget build(BuildContext context) {
    final status = StockStatus.from(qty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

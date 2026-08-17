import 'package:intl/intl.dart';

final _priceFormat = NumberFormat('#,##0.00');

/// Formats a number as price with space thousands separator: 1 000 000.00
String formatPrice(num n) {
  return _priceFormat.format(n).replaceAll(',', '\u00A0');
}

/// Quantity without trailing zeros: 1 -> "1", 0.5 -> "0.5", 0.05333... -> "0.0533".
/// Lines priced by sum carry long fractions; 4 decimals is the display limit.
String formatQty(num n) {
  final q = n.toDouble();
  if (q % 1 == 0) return q.toInt().toString();
  return q
      .toStringAsFixed(4)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

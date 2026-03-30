import 'package:intl/intl.dart';

final _priceFormat = NumberFormat('#,##0.00');

/// Formats a number as price with space thousands separator: 1 000 000.00
String formatPrice(num n) {
  return _priceFormat.format(n).replaceAll(',', '\u00A0');
}

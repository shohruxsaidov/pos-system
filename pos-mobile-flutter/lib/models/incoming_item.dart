import '../utils/money.dart';

class IncomingItem {
  final int? productId;
  final String productName;
  final String? barcode;
  double qty;
  double costPerUnit;
  String? expiryDate;
  String unit;

  /// Set when the user enters a total sum instead of a quantity. Authoritative
  /// over `qty * costPerUnit`; cleared whenever qty or cost is edited directly.
  double? amount;

  IncomingItem({
    this.productId,
    required this.productName,
    this.barcode,
    required this.qty,
    required this.costPerUnit,
    this.expiryDate,
    this.unit = 'шт',
    this.amount,
  });

  double get subtotal =>
      lineTotal(unitPrice: costPerUnit, qty: qty, amount: amount);

  /// Receives [sum]'s worth of this line. The sum is what gets paid, so it is
  /// kept verbatim and qty is the exact ratio — rounding that ratio to 0.053 kg
  /// would silently turn a 4 000 receipt into 3 975.
  void setAmount(double sum) {
    amount = roundMoney(sum);
    qty = costPerUnit > 0 ? amount! / costPerUnit : 0;
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'barcode': barcode,
        'qty_received': qty,
        'cost_per_unit': costPerUnit,
        'expiry_date': expiryDate,
        'unit': unit,
        'subtotal': subtotal,
      };
}

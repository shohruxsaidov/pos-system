class IncomingItem {
  final int? productId;
  final String productName;
  final String? barcode;
  double qty;
  double costPerUnit;
  String? expiryDate;
  String unit;

  IncomingItem({
    this.productId,
    required this.productName,
    this.barcode,
    required this.qty,
    required this.costPerUnit,
    this.expiryDate,
    this.unit = 'шт',
  });

  double get subtotal => qty * costPerUnit;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'barcode': barcode,
        'qty_received': qty,
        'cost_per_unit': costPerUnit,
        'expiry_date': expiryDate,
        'unit': unit,
      };
}

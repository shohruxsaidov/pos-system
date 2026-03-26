import 'product.dart';

class CartItem {
  final Product product;
  double qty;
  final double unitPrice;

  CartItem({
    required this.product,
    required this.qty,
    required this.unitPrice,
  });

  double get subtotal => qty * unitPrice;

  CartItem copyWith({double? qty}) => CartItem(
        product: product,
        qty: qty ?? this.qty,
        unitPrice: unitPrice,
      );
}

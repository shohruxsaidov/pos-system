class Product {
  final int id;
  final String? barcode;
  final String name;
  final String? categoryName;
  final int? categoryId;
  final double price;
  final double cost;
  final String unit;
  final int stockQty;
  final bool isActive;
  final List<Map<String, dynamic>> barcodes;

  const Product({
    required this.id,
    this.barcode,
    required this.name,
    this.categoryName,
    this.categoryId,
    required this.price,
    required this.cost,
    required this.unit,
    required this.stockQty,
    this.isActive = true,
    this.barcodes = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        barcode: json['barcode'] as String?,
        name: json['name'] as String,
        categoryName: json['category_name'] as String?,
        categoryId: json['category_id'] as int?,
        price: (json['price'] as num).toDouble(),
        cost: (json['cost'] as num? ?? 0).toDouble(),
        unit: json['unit'] as String? ?? 'pcs',
        stockQty: (json['stock_qty'] as num? ?? 0).toInt(),
        isActive: json['is_active'] as bool? ?? true,
        barcodes: (json['barcodes'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'barcode': barcode,
        'name': name,
        'category_name': categoryName,
        'category_id': categoryId,
        'price': price,
        'cost': cost,
        'unit': unit,
        'stock_qty': stockQty,
        'is_active': isActive,
        'barcodes': barcodes,
      };

  Product copyWith({int? stockQty, String? name}) => Product(
        id: id,
        barcode: barcode,
        name: name ?? this.name,
        categoryName: categoryName,
        categoryId: categoryId,
        price: price,
        cost: cost,
        unit: unit,
        stockQty: stockQty ?? this.stockQty,
        isActive: isActive,
        barcodes: barcodes,
      );
}

class Product {
  final int id;
  final String? barcode;
  final String name;
  final String? categoryName;
  final int? categoryId;
  final double price;
  final double cost;
  final String unit;
  final double stockQty;
  final bool isActive;
  final List<Map<String, dynamic>> barcodes;

  /// Manual position inside the product's category. 0 = unset → falls back to
  /// alphabetical, after the numbered ones.
  final int sortOrder;

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
    this.sortOrder = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: (json['id'] as num).toInt(),
        barcode: json['barcode'] as String?,
        name: json['name'] as String,
        categoryName: json['category_name'] as String?,
        categoryId: (json['category_id'] as num?)?.toInt(),
        price: (json['price'] as num).toDouble(),
        cost: (json['cost'] as num? ?? 0).toDouble(),
        unit: json['unit'] as String? ?? 'pcs',
        stockQty: (json['stock_qty'] as num? ?? 0).toDouble(),
        isActive: switch (json['is_active']) {
          bool b => b,
          num n => n != 0,
          _ => true,
        },
        barcodes: (json['barcodes'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [],
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
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
        'sort_order': sortOrder,
      };

  Product copyWith({
    double? stockQty,
    String? name,
    double? price,
    String? barcode,
    List<Map<String, dynamic>>? barcodes,
    String? unit,
    int? categoryId,
    String? categoryName,
    int? sortOrder,
  }) =>
      Product(
        id: id,
        barcode: barcode ?? this.barcode,
        name: name ?? this.name,
        categoryName: categoryName ?? this.categoryName,
        categoryId: categoryId ?? this.categoryId,
        price: price ?? this.price,
        cost: cost,
        unit: unit ?? this.unit,
        stockQty: stockQty ?? this.stockQty,
        isActive: isActive,
        barcodes: barcodes ?? this.barcodes,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

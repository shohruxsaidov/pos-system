class User {
  final int id;
  final String name;
  final String role;
  final int? warehouseId;

  const User({
    required this.id,
    required this.name,
    required this.role,
    this.warehouseId,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        role: json['role'] as String,
        warehouseId: json['warehouse_id'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'warehouse_id': warehouseId,
      };

  bool get canSell => role == 'cashier' || role == 'manager' || role == 'admin';
  bool get isWarehouse => role == 'warehouse';
  bool get isManager => role == 'manager' || role == 'admin';
}

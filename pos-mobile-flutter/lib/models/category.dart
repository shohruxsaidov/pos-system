class Category {
  final int id;
  final String name;
  final int? parentId;
  final String? color;
  final String? icon;

  const Category({
    required this.id,
    required this.name,
    this.parentId,
    this.color,
    this.icon,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        name: json['name'] as String,
        parentId: json['parent_id'] as int?,
        color: json['color'] as String?,
        icon: json['icon'] as String?,
      );
}

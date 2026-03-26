enum OfflineDraftStatus { pending, syncing, synced, error }

class OfflineDraft {
  final String id;
  final String barcode;
  final double qty;
  final String? resolvedName;
  final double? resolvedPrice;
  final DateTime createdAt;
  final OfflineDraftStatus status;
  final String? errorMessage;

  const OfflineDraft({
    required this.id,
    required this.barcode,
    required this.qty,
    this.resolvedName,
    this.resolvedPrice,
    required this.createdAt,
    this.status = OfflineDraftStatus.pending,
    this.errorMessage,
  });

  OfflineDraft copyWith({
    String? id,
    String? barcode,
    double? qty,
    String? resolvedName,
    double? resolvedPrice,
    DateTime? createdAt,
    OfflineDraftStatus? status,
    String? errorMessage,
  }) =>
      OfflineDraft(
        id: id ?? this.id,
        barcode: barcode ?? this.barcode,
        qty: qty ?? this.qty,
        resolvedName: resolvedName ?? this.resolvedName,
        resolvedPrice: resolvedPrice ?? this.resolvedPrice,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'barcode': barcode,
        'qty': qty,
        'resolvedName': resolvedName,
        'resolvedPrice': resolvedPrice,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'errorMessage': errorMessage,
      };

  factory OfflineDraft.fromJson(Map<String, dynamic> json) => OfflineDraft(
        id: json['id'] as String,
        barcode: json['barcode'] as String,
        qty: (json['qty'] as num).toDouble(),
        resolvedName: json['resolvedName'] as String?,
        resolvedPrice: json['resolvedPrice'] != null
            ? (json['resolvedPrice'] as num).toDouble()
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: OfflineDraftStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => OfflineDraftStatus.pending,
        ),
        errorMessage: json['errorMessage'] as String?,
      );
}

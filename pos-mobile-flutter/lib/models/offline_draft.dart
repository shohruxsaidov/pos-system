enum OfflineDraftStatus { pending, syncing, synced, error }

class OfflineDraft {
  final String id;
  final String barcode;
  final double qty;
  final int? productId;
  final String? resolvedName;
  final double? resolvedPrice;
  final DateTime createdAt;
  final OfflineDraftStatus status;
  final String? errorMessage;
  final String? notes;
  final int attempts;

  const OfflineDraft({
    required this.id,
    required this.barcode,
    required this.qty,
    this.productId,
    this.resolvedName,
    this.resolvedPrice,
    required this.createdAt,
    this.status = OfflineDraftStatus.pending,
    this.errorMessage,
    this.notes,
    this.attempts = 0,
  });

  /// A draft that still has to reach the server. Errored drafts count: a
  /// failure is never terminal, it just means the next attempt hasn't run yet.
  /// `syncing` counts too — a draft left in that state means the app was
  /// killed mid-sync, so it must be picked up again rather than stranded.
  bool get isRetryable => status != OfflineDraftStatus.synced;

  /// Stable idempotency key sent to the server as `client_ref`, so a retry of
  /// a sale that already committed returns the existing transaction instead of
  /// creating a duplicate. [deviceId] scopes it per install — draft ids are
  /// microsecond timestamps and could otherwise collide across phones.
  String clientRef(String deviceId) => '$deviceId-$id';

  OfflineDraft copyWith({
    String? id,
    String? barcode,
    double? qty,
    int? productId,
    String? resolvedName,
    double? resolvedPrice,
    DateTime? createdAt,
    OfflineDraftStatus? status,
    String? errorMessage,
    String? notes,
    int? attempts,
    bool clearError = false,
  }) =>
      OfflineDraft(
        id: id ?? this.id,
        barcode: barcode ?? this.barcode,
        qty: qty ?? this.qty,
        productId: productId ?? this.productId,
        resolvedName: resolvedName ?? this.resolvedName,
        resolvedPrice: resolvedPrice ?? this.resolvedPrice,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        notes: notes ?? this.notes,
        attempts: attempts ?? this.attempts,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'barcode': barcode,
        'qty': qty,
        'productId': productId,
        'resolvedName': resolvedName,
        'resolvedPrice': resolvedPrice,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'errorMessage': errorMessage,
        'notes': notes,
        'attempts': attempts,
      };

  factory OfflineDraft.fromJson(Map<String, dynamic> json) => OfflineDraft(
        id: json['id'] as String,
        barcode: json['barcode'] as String,
        qty: (json['qty'] as num).toDouble(),
        productId: (json['productId'] as num?)?.toInt(),
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
        notes: json['notes'] as String?,
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      );
}

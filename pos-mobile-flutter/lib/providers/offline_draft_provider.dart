import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/offline_draft.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/offline_queue_service.dart';

class OfflineDraftState {
  final List<OfflineDraft> drafts;
  final bool syncing;

  const OfflineDraftState({
    this.drafts = const [],
    this.syncing = false,
  });

  OfflineDraftState copyWith({
    List<OfflineDraft>? drafts,
    bool? syncing,
  }) =>
      OfflineDraftState(
        drafts: drafts ?? this.drafts,
        syncing: syncing ?? this.syncing,
      );

  List<OfflineDraft> get pending =>
      drafts.where((d) => d.status == OfflineDraftStatus.pending).toList();

  int get pendingCount => pending.length;

  /// Everything still owed to the server — queued *and* previously failed.
  /// This is what sync acts on, so a failure is retried rather than stranded.
  List<OfflineDraft> get retryable =>
      drafts.where((d) => d.isRetryable).toList();

  int get retryableCount => retryable.length;

  int get errorCount =>
      drafts.where((d) => d.status == OfflineDraftStatus.error).length;

  int get syncedCount =>
      drafts.where((d) => d.status == OfflineDraftStatus.synced).length;
}

class OfflineDraftNotifier extends Notifier<OfflineDraftState> {
  bool _disposed = false;

  @override
  OfflineDraftState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _load();
    return const OfflineDraftState();
  }

  Future<void> _load() async {
    final drafts = await loadDrafts();
    if (_disposed) return;
    // A draft persisted as `syncing` means the app died mid-request. Its
    // outcome is unknown, so put it back in the queue — the `client_ref`
    // idempotency key makes a re-send safe even if the sale did commit.
    final recovered = drafts
        .map((d) => d.status == OfflineDraftStatus.syncing
            ? d.copyWith(status: OfflineDraftStatus.pending)
            : d)
        .toList();
    state = state.copyWith(drafts: recovered);
    if (recovered.any((d) => d.status == OfflineDraftStatus.pending)) {
      await saveDrafts(recovered);
    }
  }

  /// Queue a draft sale. Pass [product] when it was already resolved (e.g.
  /// picked from a name search) so the draft carries its id — otherwise it is
  /// resolved from the cache by [barcode].
  Future<void> addDraft(String barcode, double qty,
      {String? notes, Product? product}) async {
    final resolved = product ?? await resolveProductByBarcode(barcode);
    final draft = OfflineDraft(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      barcode: barcode,
      qty: qty,
      productId: resolved?.id,
      resolvedName: resolved?.name,
      resolvedPrice: resolved?.price,
      createdAt: DateTime.now(),
      status: OfflineDraftStatus.pending,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
    );
    final updated = [...state.drafts, draft];
    state = state.copyWith(drafts: updated);
    await saveDrafts(updated);
    Sentry.metrics.count('offline_drafts.created', 1);
    Sentry.metrics.gauge('offline_drafts.pending', updated.where((d) => d.status == OfflineDraftStatus.pending).length.toDouble());
  }

  Future<void> clearSynced() async {
    final updated = state.drafts
        .where((d) => d.status != OfflineDraftStatus.synced)
        .toList();
    state = state.copyWith(drafts: updated);
    await saveDrafts(updated);
  }

  Future<void> deleteDraft(String id) async {
    final updated = state.drafts.where((d) => d.id != id).toList();
    state = state.copyWith(drafts: updated);
    await saveDrafts(updated);
  }

  /// Push every unsynced draft — queued and previously failed alike.
  Future<void> syncAll() => _sync(state.retryable);

  /// Re-attempt a single draft, typically an errored one from its row button.
  /// A draft deleted between build and tap is simply a no-op.
  Future<void> retryDraft(String id) {
    final idx = state.drafts.indexWhere((d) => d.id == id);
    if (idx < 0 || !state.drafts[idx].isRetryable) return Future.value();
    return _sync([state.drafts[idx]]);
  }

  Future<void> _sync(List<OfflineDraft> targets) async {
    if (targets.isEmpty || state.syncing) return;

    Sentry.logger.fmt.info('Offline sync started: %s drafts', [targets.length]);
    if (_disposed) return;
    state = state.copyWith(syncing: true);

    final device = await deviceId();
    if (_disposed) return;

    final updatedDrafts = List<OfflineDraft>.from(state.drafts);
    int synced = 0;
    int failed = 0;

    void put(int idx, OfflineDraft d) {
      updatedDrafts[idx] = d;
      state = state.copyWith(drafts: List.from(updatedDrafts));
    }

    for (final target in targets) {
      if (_disposed) break;

      final idx = updatedDrafts.indexWhere((d) => d.id == target.id);
      if (idx < 0) continue;
      final draft = updatedDrafts[idx].copyWith(
        attempts: updatedDrafts[idx].attempts + 1,
        clearError: true,
      );
      put(idx, draft.copyWith(status: OfflineDraftStatus.syncing));

      // Resolve product — prefer the stored id (set for name-picked drafts),
      // falling back to the barcode for older/scan-only drafts.
      final product = (draft.productId != null
              ? await resolveProductById(draft.productId!)
              : null) ??
          await resolveProductByBarcode(draft.barcode);
      if (_disposed) break;
      if (product == null) {
        Sentry.logger.warn('Offline sync: product not found for barcode ${draft.barcode} (draft ${draft.id})');
        put(
          idx,
          draft.copyWith(
            status: OfflineDraftStatus.error,
            errorMessage: 'Товар не найден в кэше',
          ),
        );
        failed++;
        continue;
      }

      final subtotal = product.price * draft.qty;
      final payload = {
        'items': [
          {
            'product_id': product.id,
            'qty': draft.qty,
            'unit_price': product.price,
            'discount': 0,
            'subtotal': subtotal,
          }
        ],
        'subtotal': subtotal,
        'discount': 0,
        'tax': 0,
        'total': subtotal,
        'payment_method': 'cash',
        'tendered': subtotal,
        // Stable across retries — the server returns the already-committed
        // transaction instead of ringing up the sale a second time.
        'client_ref': draft.clientRef(device),
        if (draft.notes != null && draft.notes!.isNotEmpty) 'notes': draft.notes,
      };

      try {
        await apiService.post('/api/transactions', data: payload);
        if (_disposed) break;
        put(idx, draft.copyWith(status: OfflineDraftStatus.synced));
        synced++;
      } catch (e, st) {
        Sentry.logger.fmt.error('Offline sync failed for draft %s: %s', [draft.id, e]);
        await Sentry.captureException(e, stackTrace: st);
        if (_disposed) break;
        put(
          idx,
          draft.copyWith(
            status: OfflineDraftStatus.error,
            errorMessage: e.toString(),
          ),
        );
        failed++;
      }
    }

    await saveDrafts(updatedDrafts);
    if (_disposed) return;
    state = state.copyWith(syncing: false);
    Sentry.logger.fmt.info('Offline sync complete: %s synced, %s failed', [synced, failed]);
    if (synced > 0) Sentry.metrics.count('offline_drafts.synced', synced);
    if (failed > 0) Sentry.metrics.count('offline_drafts.sync_failed', failed);
    Sentry.metrics.gauge('offline_drafts.pending', updatedDrafts.where((d) => d.isRetryable).length.toDouble());
  }
}

final offlineDraftProvider =
    NotifierProvider<OfflineDraftNotifier, OfflineDraftState>(OfflineDraftNotifier.new);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/offline_draft.dart';
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

  int get syncedCount =>
      drafts.where((d) => d.status == OfflineDraftStatus.synced).length;
}

class OfflineDraftNotifier extends Notifier<OfflineDraftState> {
  @override
  OfflineDraftState build() {
    _load();
    return const OfflineDraftState();
  }

  Future<void> _load() async {
    final drafts = await loadDrafts();
    state = state.copyWith(drafts: drafts);
  }

  Future<void> addDraft(String barcode, double qty, {String? notes}) async {
    final product = await resolveProductByBarcode(barcode);
    final draft = OfflineDraft(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      barcode: barcode,
      qty: qty,
      resolvedName: product?.name,
      resolvedPrice: product?.price,
      createdAt: DateTime.now(),
      status: OfflineDraftStatus.pending,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
    );
    final updated = [...state.drafts, draft];
    state = state.copyWith(drafts: updated);
    await saveDrafts(updated);
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

  Future<void> syncAll() async {
    final pending = state.pending;
    if (pending.isEmpty) return;

    Sentry.logger.fmt.info('Offline sync started: %d drafts pending', [pending.length]);
    state = state.copyWith(syncing: true);

    final updatedDrafts = List<OfflineDraft>.from(state.drafts);
    int synced = 0;
    int failed = 0;

    for (final draft in pending) {
      // Mark as syncing
      final syncingIdx = updatedDrafts.indexWhere((d) => d.id == draft.id);
      if (syncingIdx < 0) continue;
      updatedDrafts[syncingIdx] = draft.copyWith(status: OfflineDraftStatus.syncing);
      state = state.copyWith(drafts: List.from(updatedDrafts));

      // Resolve product
      final product = await resolveProductByBarcode(draft.barcode);
      if (product == null) {
        Sentry.logger.fmt.warning('Offline sync: product not found for barcode %s (draft %s)', [draft.barcode, draft.id]);
        updatedDrafts[syncingIdx] = draft.copyWith(
          status: OfflineDraftStatus.error,
          errorMessage: 'Product not found in cache',
        );
        state = state.copyWith(drafts: List.from(updatedDrafts));
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
        if (draft.notes != null && draft.notes!.isNotEmpty) 'notes': draft.notes,
      };

      try {
        await apiService.post('/api/transactions', data: payload);
        updatedDrafts[syncingIdx] = draft.copyWith(status: OfflineDraftStatus.synced);
        synced++;
      } catch (e, st) {
        Sentry.logger.fmt.error('Offline sync failed for draft %s: %s', [draft.id, e]);
        await Sentry.captureException(e, stackTrace: st);
        updatedDrafts[syncingIdx] = draft.copyWith(
          status: OfflineDraftStatus.error,
          errorMessage: e.toString(),
        );
        failed++;
      }
      state = state.copyWith(drafts: List.from(updatedDrafts));
    }

    await saveDrafts(updatedDrafts);
    state = state.copyWith(syncing: false);
    Sentry.logger.fmt.info('Offline sync complete: %d synced, %d failed', [synced, failed]);
  }
}

final offlineDraftProvider =
    NotifierProvider<OfflineDraftNotifier, OfflineDraftState>(OfflineDraftNotifier.new);

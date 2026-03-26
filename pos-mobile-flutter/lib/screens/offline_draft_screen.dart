import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../models/offline_draft.dart';
import '../models/product.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_draft_provider.dart';
import '../services/offline_queue_service.dart';
import '../widgets/bottom_numpad.dart';
import 'qr_scanner_screen.dart';

class OfflineDraftScreen extends ConsumerStatefulWidget {
  const OfflineDraftScreen({super.key});

  @override
  ConsumerState<OfflineDraftScreen> createState() => _OfflineDraftScreenState();
}

class _OfflineDraftScreenState extends ConsumerState<OfflineDraftScreen> {
  final _barcodeCtrl = TextEditingController();
  final _qtyFocus = FocusNode();
  final _barcodeFocus = FocusNode();
  String _qtyValue = '1';
  Product? _resolvedProduct;

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _qtyFocus.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeChanged(String barcode) async {
    if (barcode.isEmpty) {
      setState(() => _resolvedProduct = null);
      return;
    }
    final product = await resolveProductByBarcode(barcode);
    if (mounted) setState(() => _resolvedProduct = product);
  }

  Future<void> _openScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result != null && result.isNotEmpty) {
      _barcodeCtrl.text = result;
      await _onBarcodeChanged(result);
    }
  }

  Future<void> _openNumpad() async {
    final result = await BottomNumPad.show(
      context,
      title: 'Quantity',
      initialValue: _qtyValue,
      allowDecimal: true,
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _qtyValue = result);
    }
  }

  Future<void> _submit() async {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a barcode'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final qty = double.tryParse(_qtyValue);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    await ref.read(offlineDraftProvider.notifier).addDraft(barcode, qty);
    _barcodeCtrl.clear();
    setState(() {
      _resolvedProduct = null;
      _qtyValue = '1';
    });
    _barcodeFocus.requestFocus();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved'),
          backgroundColor: AppColors.successBg,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draftState = ref.watch(offlineDraftProvider);
    final fmt = NumberFormat('#,##0.00');
    final timeFmt = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Draft Sales',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _SyncButton(onSync: () => ref.read(offlineDraftProvider.notifier).syncAll()),
                ],
              ),
            ),

            const Divider(color: AppColors.borderSubtle, height: 1),

            // ── Input form ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barcode field
                  TextField(
                    controller: _barcodeCtrl,
                    focusNode: _barcodeFocus,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Scan or type barcode',
                      prefixIcon: const Icon(Icons.qr_code, color: AppColors.textMuted),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: AppColors.textMuted),
                        onPressed: _openScanner,
                      ),
                    ),
                    onChanged: _onBarcodeChanged,
                    onSubmitted: (_) => _qtyFocus.requestFocus(),
                  ),

                  const SizedBox(height: 10),

                  // Product preview
                  if (_barcodeCtrl.text.isNotEmpty)
                    _resolvedProduct != null
                        ? _ProductPreviewBadge(product: _resolvedProduct!, fmt: fmt)
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_outlined,
                                    color: AppColors.warning, size: 14),
                                SizedBox(width: 6),
                                Text('Product not in cache',
                                    style: TextStyle(color: AppColors.warning, fontSize: 12)),
                              ],
                            ),
                          ),

                  if (_barcodeCtrl.text.isNotEmpty) const SizedBox(height: 10),

                  // Qty row
                  GestureDetector(
                    onTap: _openNumpad,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgInput,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.numbers, color: AppColors.textMuted, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            'Qty: $_qtyValue',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 16),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  GradientButton(
                    onTap: _submit,
                    child: const Text(
                      'Save Draft',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.borderSubtle, height: 1),

            // ── Drafts list ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
              child: Row(
                children: [
                  const Text(
                    'Unsync Drafts',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (draftState.pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${draftState.pendingCount}',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (draftState.syncedCount > 0)
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(offlineDraftProvider.notifier).clearSynced(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: Text(
                        'Clear synced (${draftState.syncedCount})',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: draftState.drafts.isEmpty
                  ? const Center(
                      child: Text(
                        'No pending drafts',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: draftState.drafts.length,
                      itemBuilder: (_, i) {
                        final draft = draftState.drafts[i];
                        return _DraftRow(
                          draft: draft,
                          fmt: fmt,
                          timeFmt: timeFmt,
                          onDelete: () =>
                              ref.read(offlineDraftProvider.notifier).deleteDraft(draft.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sync button ───────────────────────────────────────────────────────────────

class _SyncButton extends ConsumerWidget {
  final VoidCallback onSync;

  const _SyncButton({required this.onSync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final draftState = ref.watch(offlineDraftProvider);
    final canSync = isOnline && draftState.pendingCount > 0 && !draftState.syncing;

    return TextButton.icon(
      onPressed: canSync ? onSync : null,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent1,
        disabledForegroundColor: AppColors.textMuted.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: draftState.syncing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent1),
            )
          : const Icon(Icons.sync, size: 18),
      label: Text(
        draftState.syncing
            ? 'Syncing...'
            : 'Sync (${draftState.pendingCount})',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Product preview badge ─────────────────────────────────────────────────────

class _ProductPreviewBadge extends StatelessWidget {
  final Product product;
  final NumberFormat fmt;

  const _ProductPreviewBadge({required this.product, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              product.name,
              style: const TextStyle(
                color: AppColors.textAccent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            fmt.format(product.price),
            style: const TextStyle(
              color: AppColors.textAccent,
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Draft row ─────────────────────────────────────────────────────────────────

class _DraftRow extends StatelessWidget {
  final OfflineDraft draft;
  final NumberFormat fmt;
  final DateFormat timeFmt;
  final VoidCallback onDelete;

  const _DraftRow({
    required this.draft,
    required this.fmt,
    required this.timeFmt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.resolvedName ?? draft.barcode,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Barcode: ${draft.barcode}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Qty: ${draft.qty % 1 == 0 ? draft.qty.toInt() : draft.qty}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    if (draft.resolvedPrice != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        fmt.format(draft.resolvedPrice! * draft.qty),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  timeFmt.format(draft.createdAt),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(draft: draft),
          if (draft.status != OfflineDraftStatus.synced) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.danger,
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final OfflineDraft draft;

  const _StatusBadge({required this.draft});

  @override
  Widget build(BuildContext context) {
    switch (draft.status) {
      case OfflineDraftStatus.pending:
        return _badge('Pending', AppColors.warning, AppColors.warningBg);
      case OfflineDraftStatus.syncing:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.accent1,
              ),
            ),
            const SizedBox(width: 4),
            Text('Syncing', style: TextStyle(color: AppColors.accent1, fontSize: 11)),
          ],
        );
      case OfflineDraftStatus.synced:
        return _badge('Synced', AppColors.success, AppColors.successBg);
      case OfflineDraftStatus.error:
        return Tooltip(
          message: draft.errorMessage ?? 'Unknown error',
          child: _badge('Error', AppColors.danger, AppColors.dangerBg),
        );
    }
  }

  Widget _badge(String label, Color text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

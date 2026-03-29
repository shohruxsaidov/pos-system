import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/app_theme.dart';
import '../models/incoming_item.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/bottom_numpad.dart';
import '../widgets/highlight_text.dart';

const _units = ['шт', 'кг', 'г', 'л', 'упак', 'коробка'];

class IncomingScreen extends ConsumerStatefulWidget {
  const IncomingScreen({super.key});

  @override
  ConsumerState<IncomingScreen> createState() => _IncomingScreenState();
}

class _IncomingScreenState extends ConsumerState<IncomingScreen> {
  final List<IncomingItem> _items = [];
  bool _submitting = false;
  String? _error;

  final _fmt = NumberFormat('#,##0.00');

  double get _total => _items.fold(0.0, (s, i) => s + i.subtotal);

  void _addProduct(Product product) {
    final idx = _items.indexWhere((i) => i.productId == product.id);
    if (idx >= 0) {
      setState(() => _items[idx].qty += 1);
    } else {
      setState(() {
        _items.insert(
          0,
          IncomingItem(
            productId: product.id,
            productName: product.name,
            barcode: product.barcode,
            qty: 1,
            costPerUnit: product.cost,
            unit: product.unit.isNotEmpty ? product.unit : 'шт',
          ),
        );
      });
    }
  }

  void _addCreatedProduct(Map<String, dynamic> data) {
    setState(() {
      _items.insert(
        0,
        IncomingItem(
          productId: (data['id'] as num?)?.toInt(),
          productName: data['name'] as String? ?? '',
          barcode: data['barcode'] as String?,
          qty: 1,
          costPerUnit: (data['cost'] ?? data['price'] ?? 0).toDouble(),
          unit: data['unit'] as String? ?? 'шт',
        ),
      );
    });
  }

  void _openManualAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManualAddSheet(
        onSelected: (p) {
          Navigator.pop(context);
          _addProduct(p);
        },
        onCreateNew: (prefillName) {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) _showNotFound(null, prefillName: prefillName);
          });
        },
      ),
    );
  }

  void _showNotFound(String? barcode, {String prefillName = ''}) {
    // If searched text is all digits, treat it as a barcode
    final isNumeric =
        prefillName.isNotEmpty && RegExp(r'^\d+$').hasMatch(prefillName);
    showDialog(
      context: context,
      builder: (_) => _ProductNotFoundDialog(
        barcode: barcode ?? (isNumeric ? prefillName : ''),
        prefillName: isNumeric ? '' : prefillName,
        onCreated: (data) {
          Navigator.pop(context);
          _addCreatedProduct(data);
        },
      ),
    );
  }

  Future<void> _editField(int idx, String field) async {
    final item = _items[idx];
    final title = field == 'qty'
        ? 'Количество'
        : field == 'cost'
            ? 'Цена за единицу'
            : 'Общая сумма';
    final initial = field == 'qty'
        ? item.qty.toStringAsFixed(0)
        : field == 'cost'
            ? item.costPerUnit.toString()
            : item.subtotal.toString();

    final result = await BottomNumPad.show(
      context,
      title: title,
      initialValue: initial,
      allowDecimal: field != 'qty',
    );
    if (result == null || result.isEmpty) return;
    final v = double.tryParse(result) ?? 0;
    setState(() {
      if (field == 'qty') {
        _items[idx].qty = v;
      } else if (field == 'cost') {
        _items[idx].costPerUnit = v;
      } else {
        // edit total → recalculate qty
        final cost = _items[idx].costPerUnit;
        _items[idx].qty = cost > 0 ? double.parse((v / cost).toStringAsFixed(3)) : 0;
      }
    });
  }

  Future<void> _editExpiry(int idx) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      helpText: 'Срок годности',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent1,
            surface: AppColors.bgElevated,
            onSurface: AppColors.textPrimary,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: AppColors.bgElevated),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() =>
          _items[idx].expiryDate = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _submit() async {
    if (_items.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = ref.read(authProvider);
    Sentry.logger.fmt.info('Incoming receipt submission started: %d items total=%s', [_items.length, _fmt.format(_total)]);
    try {
      final res = await apiService.post('/api/incoming', data: {
        'received_by': auth.user!.id,
        'items': _items.map((i) => i.toJson()).toList(),
      });
      final data = res.data as Map<String, dynamic>;
      final refNo = data['ref_no'] ?? '';
      final totalCost = _fmt.format(_total);
      Sentry.logger.fmt.info('Incoming receipt confirmed: ref=%s total=%s', [refNo, totalCost]);
      setState(() {
        _items.clear();
        _submitting = false;
      });
      if (mounted) {
        _showSnack('Приёмка подтверждена: $refNo — $totalCost');
      }
    } catch (e, st) {
      Sentry.logger.fmt.error('Incoming receipt submission failed: %s', [e]);
      await Sentry.captureException(e, stackTrace: st);
      setState(() {
        _error = 'Ошибка отправки: $e';
        _submitting = false;
      });
    }
  }

  void _showSnack(String msg, {bool isInfo = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isInfo ? AppColors.bgElevated : AppColors.successBg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Приёмка товара',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_items.length} позиций',
                    style: const TextStyle(
                      color: AppColors.textAccent,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Manual add button
                  GestureDetector(
                    onTap: _openManualAdd,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.accent1.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.add,
                          color: AppColors.textAccent, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Items list
            Expanded(
              child: _items.isEmpty
                  ? _EmptyState(onAdd: _openManualAdd)
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _IncomingItemCard(
                        item: _items[i],
                        onRemove: () =>
                            setState(() => _items.removeAt(i)),
                        onEditField: (field) => _editField(i, field),
                        onEditExpiry: () => _editExpiry(i),
                        onEditUnit: (unit) =>
                            setState(() => _items[i].unit = unit),
                      ),
                    ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).viewPadding.bottom + 12),
              decoration: const BoxDecoration(
                color: AppColors.bgSidebar,
                border:
                    Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    Text(_error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13)),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Итого',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15)),
                      ShaderMask(
                        shaderCallback: (b) =>
                            AppColors.gradientHero.createShader(b),
                        child: Text(
                          _fmt.format(_total),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap:
                        _submitting || _items.isEmpty ? null : _submit,
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: (_submitting || _items.isEmpty)
                            ? null
                            : AppColors.gradientHero,
                        color: (_submitting || _items.isEmpty)
                            ? AppColors.bgSurface
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: (_submitting || _items.isEmpty)
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.accent1.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      alignment: Alignment.center,
                      child: _submitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Подтвердить приёмку (${_items.length} поз.)',
                              style: TextStyle(
                                color: _items.isEmpty
                                    ? AppColors.textMuted
                                    : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_circle_outline,
              color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          const Text('Нажмите + чтобы добавить товар',
              style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.accent1.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: AppColors.textAccent, size: 18),
                  SizedBox(width: 8),
                  Text('Добавить',
                      style: TextStyle(
                          color: AppColors.textAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Incoming Item Card ──────────────────────────────────────────────────────

class _IncomingItemCard extends StatelessWidget {
  final IncomingItem item;
  final VoidCallback onRemove;
  final void Function(String field) onEditField;
  final VoidCallback onEditExpiry;
  final void Function(String unit) onEditUnit;

  const _IncomingItemCard({
    required this.item,
    required this.onRemove,
    required this.onEditField,
    required this.onEditExpiry,
    required this.onEditUnit,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.gradientCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: name + remove
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.barcode ?? 'Без штрихкода',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close,
                      color: AppColors.danger, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3-column: Qty | Cost/unit | Expiry
          Row(
            children: [
              Expanded(
                child: _FieldButton(
                  label: 'КОЛ-ВО',
                  value: item.qty % 1 == 0
                      ? item.qty.toInt().toString()
                      : item.qty.toStringAsFixed(3),
                  icon: Icons.edit_outlined,
                  onTap: () => onEditField('qty'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FieldButton(
                  label: 'ЦЕНА/ЕД.',
                  value: fmt.format(item.costPerUnit),
                  icon: Icons.edit_outlined,
                  onTap: () => onEditField('cost'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FieldButton(
                  label: 'СРОК ГОДН.',
                  value: item.expiryDate ?? 'Нет',
                  icon: Icons.calendar_today_outlined,
                  onTap: onEditExpiry,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Unit chips
          Row(
            children: [
              const Text(
                'ЕДИНИЦА',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _units
                        .map((u) => _UnitChip(
                              label: u,
                              active: item.unit == u,
                              onTap: () => onEditUnit(u),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Subtotal row (tappable)
          GestureDetector(
            onTap: () => onEditField('total'),
            child: Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Сумма',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (b) =>
                            AppColors.gradientHero.createShader(b),
                        child: Text(
                          fmt.format(item.subtotal),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_outlined,
                          color: AppColors.textMuted, size: 13),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _FieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(value,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(icon, color: AppColors.textMuted, size: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _UnitChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent1.withValues(alpha: 0.15)
              : AppColors.bgInput,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.accent1 : AppColors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.textAccent : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Manual Add Sheet ────────────────────────────────────────────────────────

class _ManualAddSheet extends StatefulWidget {
  final void Function(Product) onSelected;
  final void Function(String prefillName) onCreateNew;

  const _ManualAddSheet({
    required this.onSelected,
    required this.onCreateNew,
  });

  @override
  State<_ManualAddSheet> createState() => _ManualAddSheetState();
}

class _ManualAddSheetState extends State<_ManualAddSheet> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _searched = false;
      });
      return;
    }
    setState(() => _loading = true);

    Map<String, dynamic>? barcodeMatch;
    List<Map<String, dynamic>> nameResults = [];

    // 1. Try exact barcode lookup
    try {
      final bRes = await apiService.get(
          '/api/products/barcode/${Uri.encodeComponent(q.trim())}');
      barcodeMatch = bRes.data as Map<String, dynamic>;
    } catch (_) {}

    // 2. Also search by name
    try {
      final res = await apiService
          .get('/api/products?search=${Uri.encodeComponent(q.trim())}&limit=30');
      final data = res.data;
      if (data is List) {
        nameResults = data.cast<Map<String, dynamic>>();
      } else if (data is Map) {
        final inner = data['data'] ?? data['products'] ?? [];
        nameResults = (inner as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    // Merge: barcode match first, then name results (deduplicated)
    final List<Map<String, dynamic>> merged = [];
    if (barcodeMatch != null) {
      merged.add(barcodeMatch);
    }
    for (final p in nameResults) {
      if (barcodeMatch == null || p['id'] != barcodeMatch['id']) {
        merged.add(p);
      }
    }

    setState(() {
      _results = merged;
      _loading = false;
      _searched = true;
    });
  }

  Color _stockColor(int qty) {
    if (qty <= 0) return AppColors.danger;
    if (qty <= 5) return AppColors.warning;
    return AppColors.success;
  }

  Color _stockBg(int qty) {
    if (qty <= 0) return AppColors.dangerBg;
    if (qty <= 5) return AppColors.warningBg;
    return AppColors.successBg;
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim();
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: AppColors.borderDefault,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Добавить товар',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close,
                        color: AppColors.textSecondary, size: 16),
                  ),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(Icons.search,
                        color: AppColors.textMuted, size: 20),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Название или штрихкод...',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: (v) {
                        setState(() {}); // rebuild clear button
                        // debounce via a simple approach
                        Future.delayed(const Duration(milliseconds: 300),
                            () {
                          if (_searchCtrl.text == v) _search(v);
                        });
                      },
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() {
                          _results = [];
                          _searched = false;
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.close,
                            color: AppColors.textMuted, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Results
          Flexible(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(
                          color: AppColors.accent1),
                    ),
                  )
                : q.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search,
                                  color: AppColors.textMuted, size: 36),
                              SizedBox(height: 12),
                              Text('Введите название или штрихкод товара',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 15),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      )
                    : _searched && _results.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2_outlined,
                                      color: AppColors.textMuted, size: 36),
                                  const SizedBox(height: 12),
                                  const Text('Товар не найден',
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 15)),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: () =>
                                        widget.onCreateNew(q),
                                    child: Container(
                                      height: 52,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24),
                                      decoration: BoxDecoration(
                                        color: AppColors.bgSurface,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppColors.borderDefault),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add,
                                              color: AppColors.textAccent,
                                              size: 18),
                                          SizedBox(width: 8),
                                          Text('Создать новый товар',
                                              style: TextStyle(
                                                  color: AppColors.textAccent,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _results.length,
                            itemBuilder: (_, i) {
                              final p = _results[i];
                              final stock = ((p['stock_qty'] ?? 0) as num).toInt();
                              return GestureDetector(
                                onTap: () =>
                                    widget.onSelected(Product.fromJson(p)),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgSurface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: AppColors.borderSubtle),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            HighlightText(
                                              text: p['name'] as String? ?? '',
                                              query: _searchCtrl.text.trim(),
                                              style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            HighlightText(
                                              text: '${p['barcode'] ?? '—'} · ${p['unit'] ?? 'шт'}',
                                              query: _searchCtrl.text.trim(),
                                              style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 12,
                                                  fontFamily: 'monospace'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _stockBg(stock),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$stock',
                                          style: TextStyle(
                                            color: _stockColor(stock),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.add,
                                          color: AppColors.textAccent,
                                          size: 20),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Product Not Found Dialog ────────────────────────────────────────────────

class _ProductNotFoundDialog extends StatefulWidget {
  final String barcode;
  final String prefillName;
  final void Function(Map<String, dynamic>) onCreated;

  const _ProductNotFoundDialog({
    required this.barcode,
    required this.prefillName,
    required this.onCreated,
  });

  @override
  State<_ProductNotFoundDialog> createState() =>
      _ProductNotFoundDialogState();
}

String _generateBarcode() {
  final base = '200${Random().nextInt(999999).toString().padLeft(6, '0')}';
  int sum = 0;
  for (int i = 0; i < base.length; i++) {
    sum += int.parse(base[i]) * (i % 2 == 0 ? 1 : 3);
  }
  return '$base${(10 - (sum % 10)) % 10}';
}

class _ProductNotFoundDialogState extends State<_ProductNotFoundDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  final _priceCtrl = TextEditingController();
  String _unit = 'шт';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.prefillName);
    _barcodeCtrl = TextEditingController(
      text: widget.barcode.isNotEmpty ? widget.barcode : _generateBarcode(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final barcode = _barcodeCtrl.text.trim();
      final res = await apiService.post('/api/products', data: {
        'barcode': barcode.isNotEmpty ? barcode : null,
        'name': _nameCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'cost': 0,
        'unit': _unit,
        'is_active': true,
      });
      widget.onCreated(res.data as Map<String, dynamic>);
    } catch (e) {
      setState(() {
        _error = 'Ошибка создания товара';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgElevated,
      title: const Text('Товар не найден',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _barcodeCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(
                color: AppColors.textPrimary, fontFamily: 'monospace'),
            decoration: const InputDecoration(labelText: 'Штрихкод'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Название товара'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Цена'),
          ),
          const SizedBox(height: 12),
          const Text('ЕДИНИЦА',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _units
                  .map((u) => _UnitChip(
                        label: u,
                        active: _unit == u,
                        onTap: () => setState(() => _unit = u),
                      ))
                  .toList(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _loading ? null : _create,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: AppColors.accent1, strokeWidth: 2))
              : const Text('Создать',
                  style: TextStyle(color: AppColors.accent1)),
        ),
      ],
    );
  }
}

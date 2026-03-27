import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../models/product.dart';
import '../providers/warehouse_provider.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';
import '../widgets/stock_adjust_sheet.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all'; // all | low | oversold

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(warehouseProvider.notifier).fetchProducts();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _filtered(List<Product> products) {
    var list = products;
    if (_filter == 'low') {
      list = list.where((p) => p.stockQty > 0 && p.stockQty <= 5).toList();
    } else if (_filter == 'oversold') {
      list = list.where((p) => p.stockQty < 0).toList()
        ..sort((a, b) => a.stockQty.compareTo(b.stockQty));
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              (p.barcode?.contains(q) ?? false) ||
              p.barcodes.any((b) =>
                  (b['barcode'] as String? ?? '').contains(q)))
          .toList();
    }
    return list;
  }

  void _openAdjust(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StockAdjustSheet(
        product: product,
        onDone: () {
          Navigator.pop(context);
          ref.read(warehouseProvider.notifier).fetchProducts();
        },
      ),
    );
  }

  void _openPrint(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrintSheet(product: product),
    );
  }

  void _openRename(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RenameSheet(
        product: product,
        onSaved: (newName) {
          Navigator.pop(context);
          ref
              .read(warehouseProvider.notifier)
              .renameProduct(product.id, newName);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Название изменено')),
          );
        },
      ),
    );
  }

  void _openAddBarcode(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBarcodeSheet(
        product: product,
        onSaved: (barcodes) async {
          Navigator.pop(context);
          await ref
              .read(warehouseProvider.notifier)
              .updateBarcodes(product.id, barcodes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Штрихкоды обновлены')),
            );
          }
        },
        onGenerate: (id) => ref
            .read(warehouseProvider.notifier)
            .generateBarcode(id),
      ),
    );
  }

  void _openChangePrice(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePriceSheet(
        product: product,
        onSaved: (newPrice) {
          Navigator.pop(context);
          ref
              .read(warehouseProvider.notifier)
              .updatePrice(product.id, newPrice);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Цена изменена')),
          );
        },
      ),
    );
  }

  String _formatCompact(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(warehouseProvider);
    final filtered = _filtered(state.products);

    final lowCount =
        state.products.where((p) => p.stockQty > 0 && p.stockQty <= 5).length;
    final oversoldCount =
        state.products.where((p) => p.stockQty < 0).length;

    final totalValue = filtered.fold<double>(
        0, (s, p) => s + p.price * (p.stockQty > 0 ? p.stockQty : 0));

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(Icons.search,
                        color: AppColors.textMuted, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'Поиск или сканирование...',
                          hintStyle:
                              TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.close,
                              color: AppColors.textMuted, size: 18),
                        ),
                      )
                    else
                      const SizedBox(width: 12),
                  ],
                ),
              ),
            ),

            // Filter tabs
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                children: [
                  _FilterTab(
                    label: 'Все',
                    active: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    label: 'Мало',
                    count: lowCount > 0 ? lowCount : null,
                    active: _filter == 'low',
                    color: AppColors.warning,
                    onTap: () => setState(() => _filter = 'low'),
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    label: 'Дефицит',
                    count: oversoldCount > 0 ? oversoldCount : null,
                    active: _filter == 'oversold',
                    color: AppColors.danger,
                    onTap: () => setState(() => _filter = 'oversold'),
                  ),
                ],
              ),
            ),

            // Stats bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${filtered.length}',
                            style: const TextStyle(
                              color: AppColors.textAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Text(
                            'ТОВАРОВ',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 36,
                        color: AppColors.borderDefault),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _formatCompact(totalValue),
                            style: const TextStyle(
                              color: AppColors.textAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Text(
                            'ОБЩАЯ СТОИМОСТЬ',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Product list
            Expanded(
              child: state.loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent1))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.inventory_2_outlined,
                                  size: 40, color: AppColors.textMuted),
                              SizedBox(height: 12),
                              Text(
                                'Товары не найдены',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.accent1,
                          backgroundColor: AppColors.bgSurface,
                          onRefresh: () => ref
                              .read(warehouseProvider.notifier)
                              .fetchProducts(),
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(12, 8, 12, 20),
                            itemCount: filtered.length + 1,
                            itemBuilder: (_, i) {
                              if (i == filtered.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      top: 12, bottom: 4),
                                  child: Text(
                                    '${filtered.length} товаров',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12),
                                  ),
                                );
                              }
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: ProductCard(
                                  product: filtered[i],
                                  query: _query,
                                  onAdjust: () =>
                                      _openAdjust(filtered[i]),
                                  onPrint: () =>
                                      _openPrint(filtered[i]),
                                  onRename: () =>
                                      _openRename(filtered[i]),
                                  onChangePrice: () =>
                                      _openChangePrice(filtered[i]),
                                  onAddBarcode: () =>
                                      _openAddBarcode(filtered[i]),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Print Sheet ──────────────────────────────────────────────────────────────

class _PrintSheet extends StatefulWidget {
  final Product product;
  const _PrintSheet({required this.product});

  @override
  State<_PrintSheet> createState() => _PrintSheetState();
}

class _PrintSheetState extends State<_PrintSheet> {
  int _copies = 1;
  late String _selectedBarcode;
  bool _printing = false;

  List<Map<String, dynamic>> get _barcodes {
    final list = widget.product.barcodes
        .where((b) => (b['barcode'] as String?)?.isNotEmpty == true)
        .toList();
    if (list.isEmpty && widget.product.barcode != null) {
      return [
        {'barcode': widget.product.barcode, 'is_primary': true}
      ];
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    final barcodes = _barcodes;
    final primary = barcodes.firstWhere(
        (b) => b['is_primary'] == true,
        orElse: () => barcodes.isNotEmpty ? barcodes.first : {});
    _selectedBarcode =
        (primary['barcode'] as String?) ?? widget.product.barcode ?? '';
  }

  Future<void> _sendPrint() async {
    if (_printing || _selectedBarcode.isEmpty) return;
    setState(() => _printing = true);
    try {
      await apiService.post('/api/barcode/print', data: {
        'product_id': widget.product.id,
        'barcode': _selectedBarcode,
        'product_name': widget.product.name,
        'price': widget.product.price,
        'copies': _copies,
        'size': '58mm',
        'source': 'mobile',
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Печать отправлена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.dangerBg,
          ),
        );
        setState(() => _printing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final barcodes = _barcodes;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const Text(
              'Печать этикетки',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            Text(
              widget.product.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Barcode preview
            if (_selectedBarcode.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: _selectedBarcode,
                  width: double.infinity,
                  height: 60,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontFamily: 'monospace'),
                ),
              ),

            // Barcode selector (only if multiple)
            if (barcodes.length > 1) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ШТРИХКОД',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              ...barcodes.map((bc) {
                final code = bc['barcode'] as String? ?? '';
                final isPrimary = bc['is_primary'] == true;
                final active = _selectedBarcode == code;
                return GestureDetector(
                  onTap: () => setState(() => _selectedBarcode = code),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.accentGlow
                          : AppColors.bgInput,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: active
                              ? AppColors.accent1
                              : AppColors.borderDefault),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            code,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontFamily: 'monospace',
                                fontSize: 13),
                          ),
                        ),
                        if (isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'основной',
                              style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],

            // Copies control
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Копии',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 15)),
                Row(
                  children: [
                    _CopiesBtn(
                      icon: Icons.remove,
                      onTap: () {
                        if (_copies > 1) setState(() => _copies--);
                      },
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$_copies',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace'),
                      ),
                    ),
                    _CopiesBtn(
                      icon: Icons.add,
                      onTap: () {
                        if (_copies < 20) setState(() => _copies++);
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Print button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.gradientHero,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextButton(
                  onPressed: _printing ? null : _sendPrint,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _printing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.print, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Печать $_copies шт.',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Barcode Sheet ────────────────────────────────────────────────────────

class _AddBarcodeSheet extends StatefulWidget {
  final Product product;
  final Future<void> Function(List<Map<String, dynamic>>) onSaved;
  final Future<String> Function(int) onGenerate;

  const _AddBarcodeSheet({
    required this.product,
    required this.onSaved,
    required this.onGenerate,
  });

  @override
  State<_AddBarcodeSheet> createState() => _AddBarcodeSheetState();
}

class _AddBarcodeSheetState extends State<_AddBarcodeSheet> {
  late List<Map<String, dynamic>> _barcodes;
  final _newCtrl = TextEditingController();
  bool _saving = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _barcodes = widget.product.barcodes
        .where((b) => (b['barcode'] as String?)?.isNotEmpty == true)
        .map((b) => Map<String, dynamic>.from(b))
        .toList();
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  void _setPrimary(int index) {
    setState(() {
      for (int i = 0; i < _barcodes.length; i++) {
        _barcodes[i] = {..._barcodes[i], 'is_primary': i == index ? 1 : 0};
      }
    });
  }

  void _remove(int index) {
    setState(() {
      _barcodes.removeAt(index);
      if (_barcodes.isNotEmpty &&
          !_barcodes.any(
              (b) => b['is_primary'] == 1 || b['is_primary'] == true)) {
        _barcodes[0] = {..._barcodes[0], 'is_primary': 1};
      }
    });
  }

  void _addNew() {
    final code = _newCtrl.text.trim();
    if (code.isEmpty) return;
    if (_barcodes.any((b) => b['barcode'] == code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Такой штрихкод уже добавлен')),
      );
      return;
    }
    setState(() {
      _barcodes.add({
        'barcode': code,
        'is_primary': _barcodes.isEmpty ? 1 : 0,
      });
      _newCtrl.clear();
    });
  }

  Future<void> _generate() async {
    if (_generating || _saving) return;
    setState(() => _generating = true);
    try {
      final barcode = await widget.onGenerate(widget.product.id);
      if (!mounted) return;
      if (!_barcodes.any((b) => b['barcode'] == barcode)) {
        setState(() {
          _barcodes.add({
            'barcode': barcode,
            'is_primary': _barcodes.isEmpty ? 1 : 0,
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.dangerBg,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _barcodes.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSaved(_barcodes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.dangerBg,
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const Text(
              'Штрихкоды',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              widget.product.name,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Existing barcodes list
            if (_barcodes.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ТЕКУЩИЕ ШТРИХКОДЫ',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              ..._barcodes.asMap().entries.map((entry) {
                final i = entry.key;
                final bc = entry.value;
                final code = bc['barcode'] as String? ?? '';
                final isPrimary =
                    bc['is_primary'] == 1 || bc['is_primary'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? AppColors.accentGlow
                        : AppColors.bgInput,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPrimary
                          ? AppColors.accent1
                          : AppColors.borderDefault,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Primary star toggle
                      GestureDetector(
                        onTap: () => _setPrimary(i),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(
                            isPrimary
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isPrimary
                                ? AppColors.accent1
                                : AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              code,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontFamily: 'monospace',
                                  fontSize: 14),
                            ),
                            if (isPrimary)
                              const Text(
                                'основной',
                                style: TextStyle(
                                    color: AppColors.accent1,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                      // Delete
                      GestureDetector(
                        onTap: () => _remove(i),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close,
                              color: AppColors.danger, size: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              const Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 12),
            ],

            // Add new barcode
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ДОБАВИТЬ ШТРИХКОД',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCtrl,
                    autofocus: _barcodes.isEmpty,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontFamily: 'monospace'),
                    onSubmitted: (_) => _addNew(),
                    decoration: const InputDecoration(
                        hintText: 'Сканируйте или введите'),
                  ),
                ),
                const SizedBox(width: 8),
                // Add button
                GestureDetector(
                  onTap: _addNew,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: const Icon(Icons.add,
                        color: AppColors.accent1, size: 20),
                  ),
                ),
                // Auto-generate button
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _generating ? null : _generate,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: _generating
                        ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: AppColors.accent1, strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.auto_awesome,
                            color: AppColors.accent1, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Нажмите ✦ для авто-генерации · ☆ = основной',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 16),

            // Save / Cancel
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(
                            color: AppColors.borderDefault),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _barcodes.isEmpty
                            ? null
                            : AppColors.gradientHero,
                        color: _barcodes.isEmpty
                            ? AppColors.bgInput
                            : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextButton(
                        onPressed:
                            (_saving || _barcodes.isEmpty) ? null : _save,
                        style: TextButton.styleFrom(
                          foregroundColor: _barcodes.isEmpty
                              ? AppColors.textMuted
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check, size: 18),
                                  SizedBox(width: 6),
                                  Text('Сохранить',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CopiesBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CopiesBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 18),
      ),
    );
  }
}

// ─── Rename Sheet ─────────────────────────────────────────────────────────────

class _RenameSheet extends StatefulWidget {
  final Product product;
  final void Function(String) onSaved;
  const _RenameSheet({required this.product, required this.onSaved});

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.product.name);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _ctrl.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    widget.onSaved(name);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.borderDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text(
            'Изменить название',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          Text(
            widget.product.name,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _ctrl,
            autofocus: true,
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(hintText: 'Новое название'),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side:
                          const BorderSide(color: AppColors.borderDefault),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Отмена'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientHero,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextButton(
                      onPressed: _saving ? null : _save,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, size: 18),
                                SizedBox(width: 6),
                                Text('Сохранить',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Change Price Sheet ───────────────────────────────────────────────────────

class _ChangePriceSheet extends StatefulWidget {
  final Product product;
  final void Function(double) onSaved;
  const _ChangePriceSheet({required this.product, required this.onSaved});

  @override
  State<_ChangePriceSheet> createState() => _ChangePriceSheetState();
}

class _ChangePriceSheetState extends State<_ChangePriceSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.product.price.toStringAsFixed(2));
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final price = double.tryParse(_ctrl.text.trim().replaceAll(',', '.'));
    if (price == null || price < 0 || _saving) return;
    setState(() => _saving = true);
    widget.onSaved(price);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.borderDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text(
            'Изменить цену',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          Text(
            widget.product.name,
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Текущая цена: ${fmt.format(widget.product.price)}',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(hintText: 'Новая цена'),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(
                          color: AppColors.borderDefault),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Отмена'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientHero,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextButton(
                      onPressed: _saving ? null : _save,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, size: 18),
                                SizedBox(width: 6),
                                Text('Сохранить',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Filter Tab ───────────────────────────────────────────────────────────────

class _FilterTab extends StatelessWidget {
  final String label;
  final int? count;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    this.count,
    required this.active,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent1;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.15) : AppColors.bgInput,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? c : AppColors.borderDefault),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: active ? c : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

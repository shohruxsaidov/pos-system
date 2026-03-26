import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../models/incoming_item.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/bottom_numpad.dart';

class IncomingScreen extends ConsumerStatefulWidget {
  const IncomingScreen({super.key});

  @override
  ConsumerState<IncomingScreen> createState() => _IncomingScreenState();
}

class _IncomingScreenState extends ConsumerState<IncomingScreen> {
  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();
  final _supplierCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final List<IncomingItem> _items = [];
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-focus barcode input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    _supplierCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _onBarcode() async {
    final code = _barcodeCtrl.text.trim();
    if (code.isEmpty) return;
    _barcodeCtrl.clear();
    try {
      final res = await apiService.get('/api/products/barcode/$code');
      final product = Product.fromJson(res.data as Map<String, dynamic>);
      _addItem(product);
    } catch (_) {
      // Product not found — show dialog
      _showNotFound(code);
    }
  }

  void _addItem(Product product) {
    final existing = _items.indexWhere((i) => i.productId == product.id);
    if (existing >= 0) {
      setState(() => _items[existing].qty += 1);
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
              unit: product.unit,
            ));
      });
    }
  }

  void _showNotFound(String barcode) {
    showDialog(
      context: context,
      builder: (_) => _ProductNotFoundDialog(
        barcode: barcode,
        onCreated: (product) {
          Navigator.pop(context);
          _addItem(product);
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (_items.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = ref.read(authProvider);
    try {
      await apiService.post('/api/incoming', data: {
        'received_by': auth.user!.id,
        'supplier': _supplierCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'items': _items.map((i) => i.toJson()).toList(),
      });
      setState(() {
        _items.clear();
        _supplierCtrl.clear();
        _notesCtrl.clear();
        _submitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt confirmed!'),
            backgroundColor: AppColors.successBg,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Submit failed: $e';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final total = _items.fold(0.0, (s, i) => s + i.subtotal);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Barcode input (always focused)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _barcodeCtrl,
                      focusNode: _barcodeFocus,
                      onSubmitted: (_) => _onBarcode(),
                      style:
                          const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Scan barcode...',
                        prefixIcon: const Icon(Icons.qr_code_scanner,
                            color: AppColors.textMuted),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.success.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle,
                                  color: AppColors.success, size: 8),
                              SizedBox(width: 4),
                              Text('Ready',
                                  style: TextStyle(
                                      color: AppColors.success,
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Supplier / Notes
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _supplierCtrl,
                      style:
                          const TextStyle(color: AppColors.textPrimary),
                      decoration:
                          const InputDecoration(hintText: 'Supplier'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _notesCtrl,
                      style:
                          const TextStyle(color: AppColors.textPrimary),
                      decoration:
                          const InputDecoration(hintText: 'Notes'),
                    ),
                  ),
                ],
              ),
            ),

            // Items list
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              color: AppColors.textMuted, size: 48),
                          SizedBox(height: 8),
                          Text('Scan items to add',
                              style:
                                  TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _IncomingItemCard(
                        item: _items[i],
                        onQtyChanged: (v) =>
                            setState(() => _items[i].qty = v),
                        onCostChanged: (v) =>
                            setState(() => _items[i].costPerUnit = v),
                        onRemove: () => setState(() => _items.removeAt(i)),
                      ),
                    ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).viewPadding.bottom + 12),
              decoration: const BoxDecoration(
                color: AppColors.bgElevated,
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Column(
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
                      Text('${_items.length} items · Total: ${fmt.format(total)}',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                      GradientButton(
                        height: 48,
                        onTap: _submitting || _items.isEmpty
                            ? () {}
                            : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _submitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)
                              : const Text('Confirm Receipt',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
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

class _IncomingItemCard extends StatelessWidget {
  final IncomingItem item;
  final void Function(double) onQtyChanged;
  final void Function(double) onCostChanged;
  final VoidCallback onRemove;

  const _IncomingItemCard({
    required this.item,
    required this.onQtyChanged,
    required this.onCostChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.productName,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.danger, size: 18),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (item.barcode != null)
            Text(item.barcode!,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _EditableField(
                  label: 'Qty',
                  value: item.qty.toInt().toString(),
                  onTap: () async {
                    final result = await BottomNumPad.show(
                      context,
                      title: 'Quantity',
                      initialValue: item.qty.toInt().toString(),
                      allowDecimal: false,
                    );
                    if (result != null && result.isNotEmpty) {
                      final v = double.tryParse(result);
                      if (v != null) onQtyChanged(v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EditableField(
                  label: 'Cost',
                  value: fmt.format(item.costPerUnit),
                  onTap: () async {
                    final result = await BottomNumPad.show(
                      context,
                      title: 'Cost per unit',
                      initialValue: item.costPerUnit.toString(),
                      allowDecimal: true,
                    );
                    if (result != null && result.isNotEmpty) {
                      final v = double.tryParse(result);
                      if (v != null) onCostChanged(v);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Subtotal',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                  Text(
                    fmt.format(item.subtotal),
                    style: const TextStyle(
                        color: AppColors.textAccent,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _EditableField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}

class _ProductNotFoundDialog extends StatefulWidget {
  final String barcode;
  final void Function(Product) onCreated;

  const _ProductNotFoundDialog({
    required this.barcode,
    required this.onCreated,
  });

  @override
  State<_ProductNotFoundDialog> createState() =>
      _ProductNotFoundDialogState();
}

class _ProductNotFoundDialogState extends State<_ProductNotFoundDialog> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await apiService.post('/api/products', data: {
        'barcode': widget.barcode,
        'name': _nameCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'cost': 0,
        'unit': 'pcs',
        'is_active': true,
      });
      final product = Product.fromJson(res.data as Map<String, dynamic>);
      widget.onCreated(product);
    } catch (e) {
      setState(() {
        _error = 'Failed to create product';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgElevated,
      title: const Text('Product Not Found',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Barcode: ${widget.barcode}',
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontFamily: 'monospace')),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Product Name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Price'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style:
                    const TextStyle(color: AppColors.danger, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _loading ? null : _create,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create',
                  style: TextStyle(color: AppColors.accent1)),
        ),
      ],
    );
  }
}

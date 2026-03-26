import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'bottom_numpad.dart';

const _reasons = [
  'Receiving correction',
  'Damaged',
  'Count correction',
  'Return to supplier',
  'Other',
];

/// StockAdjustSheet — equivalent to StockAdjustSheet.vue
class StockAdjustSheet extends StatefulWidget {
  final Product product;
  final VoidCallback onDone;

  const StockAdjustSheet({
    super.key,
    required this.product,
    required this.onDone,
  });

  @override
  State<StockAdjustSheet> createState() => _StockAdjustSheetState();
}

class _StockAdjustSheetState extends State<StockAdjustSheet> {
  String _mode = 'add'; // add | remove | set
  double _qty = 0;
  String _reason = _reasons[0];
  bool _loading = false;
  String? _error;

  int get _preview {
    if (_mode == 'add') return widget.product.stockQty + _qty.toInt();
    if (_mode == 'remove') return widget.product.stockQty - _qty.toInt();
    return _qty.toInt();
  }

  Future<void> _submit() async {
    if (_qty == 0 && _mode != 'set') return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final delta = _mode == 'add'
          ? _qty.toInt()
          : _mode == 'remove'
              ? -_qty.toInt()
              : _qty.toInt() - widget.product.stockQty;
      await apiService.patch('/api/products/${widget.product.id}/stock',
          data: {'delta': delta, 'reason': _reason});
      widget.onDone();
    } catch (e) {
      setState(() {
        _error = 'Failed to adjust stock';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewPadding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Adjust Stock',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text(widget.product.name,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mode toggle
          Row(
            children: ['add', 'remove', 'set'].map((m) {
              final selected = _mode == m;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _mode = m),
                  child: Container(
                    margin: EdgeInsets.only(right: m == 'set' ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accentGlow
                          : AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? AppColors.accent1
                            : AppColors.borderDefault,
                      ),
                    ),
                    child: Text(
                      m[0].toUpperCase() + m.substring(1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected
                            ? AppColors.accent1
                            : AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Qty input
          GestureDetector(
            onTap: () async {
              final result = await BottomNumPad.show(
                context,
                title: 'Quantity',
                initialValue: _qty > 0 ? _qty.toString() : '',
                allowDecimal: false,
              );
              if (result != null && result.isNotEmpty) {
                setState(() => _qty = double.tryParse(result) ?? 0);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderFocus),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Quantity',
                      style: TextStyle(color: AppColors.textSecondary)),
                  Text(
                    _qty == 0 ? 'Tap to enter' : _qty.toInt().toString(),
                    style: TextStyle(
                      color: _qty == 0
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      fontSize: 16,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('New stock',
                    style: TextStyle(color: AppColors.textSecondary)),
                Text(
                  '${widget.product.stockQty} → $_preview',
                  style: TextStyle(
                    color: _preview < 0
                        ? AppColors.danger
                        : AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Reason dropdown
          DropdownButtonFormField<String>(
            value: _reason,
            dropdownColor: AppColors.bgElevated,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Reason'),
            items: _reasons
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setState(() => _reason = v!),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style:
                    const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side:
                        const BorderSide(color: AppColors.borderDefault),
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GradientButton(
                  height: 52,
                  onTap: _loading ? () {} : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : const Text('Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

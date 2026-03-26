import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import 'bottom_numpad.dart';

/// PaymentSheet — equivalent to PaymentSheet.vue
class PaymentSheet extends StatefulWidget {
  final double total;
  final void Function({
    required String method,
    required double tendered,
    required double discount,
  }) onConfirm;
  final VoidCallback onClose;

  const PaymentSheet({
    super.key,
    required this.total,
    required this.onConfirm,
    required this.onClose,
  });

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  String _method = 'cash';
  double _tendered = 0;
  double _discount = 0;
  bool _processing = false;

  final _methods = [
    {'key': 'cash', 'label': 'Cash', 'icon': Icons.money},
    {'key': 'card', 'label': 'Card', 'icon': Icons.credit_card},
    {'key': 'transfer', 'label': 'Transfer', 'icon': Icons.account_balance},
  ];

  double get _netTotal => (widget.total - _discount).clamp(0, double.infinity);
  double get _change => (_tendered - _netTotal).clamp(0, double.infinity);

  final _fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _tendered = widget.total;
  }

  Future<void> _onConfirm() async {
    setState(() => _processing = true);
    widget.onConfirm(
      method: _method,
      tendered: _tendered,
      discount: _discount,
    );
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
              const Text('Payment',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Payment method selector
          const Text('Method',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: _methods.map((m) {
              final selected = _method == m['key'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _method = m['key'] as String),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: m['key'] == 'transfer' ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accentGlow
                          : AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.accent1
                            : AppColors.borderDefault,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(m['icon'] as IconData,
                            color: selected
                                ? AppColors.accent1
                                : AppColors.textMuted,
                            size: 20),
                        const SizedBox(height: 4),
                        Text(m['label'] as String,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.accent1
                                  : AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Discount row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Discount',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final result = await BottomNumPad.show(
                          context,
                          title: 'Discount Amount',
                          initialValue: _discount > 0
                              ? _discount.toString()
                              : '',
                          allowDecimal: true,
                        );
                        if (result != null && result.isNotEmpty) {
                          final v = double.tryParse(result) ?? 0;
                          setState(() => _discount = v);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _discount > 0
                                  ? _fmt.format(_discount)
                                  : '0.00',
                              style: TextStyle(
                                color: _discount > 0
                                    ? AppColors.warning
                                    : AppColors.textMuted,
                                fontSize: 16,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const Icon(Icons.edit,
                                color: AppColors.textMuted, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tendered',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final result = await BottomNumPad.show(
                          context,
                          title: 'Amount Tendered',
                          initialValue: _tendered.toString(),
                          allowDecimal: true,
                        );
                        if (result != null && result.isNotEmpty) {
                          final v = double.tryParse(result) ?? _netTotal;
                          setState(() => _tendered = v);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderFocus),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fmt.format(_tendered),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const Icon(Icons.edit,
                                color: AppColors.textMuted, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                _SummaryRow(
                    label: 'Subtotal',
                    value: _fmt.format(widget.total)),
                if (_discount > 0)
                  _SummaryRow(
                      label: 'Discount',
                      value: '-${_fmt.format(_discount)}',
                      color: AppColors.warning),
                const Divider(color: AppColors.borderSubtle, height: 16),
                _SummaryRow(
                    label: 'Total',
                    value: _fmt.format(_netTotal),
                    large: true),
                if (_method == 'cash' && _change > 0)
                  _SummaryRow(
                      label: 'Change',
                      value: _fmt.format(_change),
                      color: AppColors.success),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Confirm button
          GradientButton(
            height: 64,
            onTap: _processing ? () {} : _onConfirm,
            child: _processing
                ? const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)
                : Text(
                    'Confirm Payment  ${_fmt.format(_netTotal)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool large;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: large ? 16 : 14,
              )),
          Text(value,
              style: TextStyle(
                color: color ?? AppColors.textPrimary,
                fontSize: large ? 18 : 14,
                fontWeight:
                    large ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'monospace',
              )),
        ],
      ),
    );
  }
}

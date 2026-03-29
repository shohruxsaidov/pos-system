import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Reusable bottom numpad sheet — equivalent to BottomNumPad.vue
class BottomNumPad extends StatefulWidget {
  final String title;
  final String? initialValue;
  final bool allowDecimal;
  final void Function(String value) onConfirm;
  final VoidCallback onCancel;

  const BottomNumPad({
    super.key,
    required this.title,
    this.initialValue,
    this.allowDecimal = true,
    required this.onConfirm,
    required this.onCancel,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? initialValue,
    bool allowDecimal = true,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NumPadSheet(
        title: title,
        initialValue: initialValue,
        allowDecimal: allowDecimal,
      ),
    );
  }

  @override
  State<BottomNumPad> createState() => _BottomNumPadState();
}

class _NumPadSheet extends StatefulWidget {
  final String title;
  final String? initialValue;
  final bool allowDecimal;

  const _NumPadSheet({
    required this.title,
    this.initialValue,
    required this.allowDecimal,
  });

  @override
  State<_NumPadSheet> createState() => _NumPadSheetState();
}

class _NumPadSheetState extends State<_NumPadSheet> {
  String _value = '';

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue ?? '';
  }

  void _onKey(String key) {
    setState(() {
      if (key == '.' && !widget.allowDecimal) return;
      if (key == '.' && _value.contains('.')) return;
      if (key == 'C') {
        _value = '';
      } else if (key == '⌫') {
        if (_value.isNotEmpty) _value = _value.substring(0, _value.length - 1);
      } else {
        _value += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.allowDecimal
        ? ['7', '8', '9', '4', '5', '6', '1', '2', '3', '.', '0', '⌫']
        : ['7', '8', '9', '4', '5', '6', '1', '2', '3', 'C', '0', '⌫'];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.borderDefault,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title + display
          Text(widget.title,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderFocus),
            ),
            child: Text(
              _value.isEmpty ? '0' : _value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(height: 16),

          // Keys grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: keys.map((k) {
              Color bg = AppColors.bgSurface;
              Color fg = AppColors.textPrimary;
              if (k == 'C') {
                bg = AppColors.dangerBg;
                fg = AppColors.danger;
              } else if (k == '⌫') {
                bg = AppColors.dangerBg;
                fg = AppColors.danger;
              }
              return Material(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _onKey(k),
                  child: Center(
                    child: Text(k,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: fg)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Confirm + Cancel
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    side: const BorderSide(color: AppColors.borderDefault),
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _GradientButton(
                  onTap: () => Navigator.pop(context, _value),
                  child: const Text('Подтвердить',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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

class _BottomNumPadState extends State<BottomNumPad> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Gradient button helper (used across many screens)
class _GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _GradientButton({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.gradientHero,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// Exported gradient button for use in other files
class GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double height;

  const GradientButton({
    super.key,
    required this.child,
    required this.onTap,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: AppColors.gradientHero,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

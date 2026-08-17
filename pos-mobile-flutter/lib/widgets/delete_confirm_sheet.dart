import 'dart:math';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Destructive-action guard: shows a random 4-digit code the user must retype
/// before the action is allowed. Prevents accidental taps on Delete.
///
/// Returns `true` only when the code was entered correctly and confirmed.
class DeleteConfirmSheet extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;

  const DeleteConfirmSheet({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Удалить',
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Удалить',
  }) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeleteConfirmSheet(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      ),
    );
    return ok == true;
  }

  @override
  State<DeleteConfirmSheet> createState() => _DeleteConfirmSheetState();
}

class _DeleteConfirmSheetState extends State<DeleteConfirmSheet> {
  /// Random 4-digit code, 1000–9999 (never leading-zero, so it always reads
  /// as four digits on screen).
  final String _code = (Random().nextInt(9000) + 1000).toString();

  String _input = '';
  bool _error = false;

  bool get _matches => _input == _code;

  void _onKey(String k) {
    if (_input.length >= 4) return;
    setState(() {
      _error = false;
      _input += k;
      if (_input.length == 4 && !_matches) {
        _error = true;
      }
    });
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() {
      _error = false;
      _input = _input.substring(0, _input.length - 1);
    });
  }

  void _confirm() {
    if (!_matches) {
      setState(() => _error = true);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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

            // Warning icon
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.dangerBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.danger, size: 26),
            ),
            const SizedBox(height: 12),

            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),

            // Code to retype
            const Text(
              'ВВЕДИТЕ КОД ДЛЯ ПОДТВЕРЖДЕНИЯ',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Text(
                _code,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  letterSpacing: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Entered digits
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _input.length;
                final borderColor = _error
                    ? AppColors.danger
                    : (filled ? AppColors.borderFocus : AppColors.borderDefault);
                return Container(
                  width: 52,
                  height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Text(
                    filled ? _input[i] : '',
                    style: TextStyle(
                      color: _error ? AppColors.danger : AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }),
            ),

            SizedBox(
              height: 26,
              child: _error
                  ? const Center(
                      child: Text(
                        'Код не совпадает',
                        style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    )
                  : null,
            ),

            // Keypad
            _CodePad(onKey: _onKey, onDelete: _onDelete),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
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
                  child: ElevatedButton(
                    onPressed: _matches ? _confirm : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: AppColors.danger,
                      disabledBackgroundColor: AppColors.dangerBg,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: AppColors.textMuted,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      widget.confirmLabel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
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

class _CodePad extends StatelessWidget {
  final void Function(String) onKey;
  final VoidCallback onDelete;

  const _CodePad({required this.onKey, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.7,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: keys.map((k) {
        if (k.isEmpty) return const SizedBox();
        return Material(
          color: k == '⌫' ? AppColors.dangerBg : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => k == '⌫' ? onDelete() : onKey(k),
            child: Center(
              child: Text(
                k,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: k == '⌫' ? AppColors.danger : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

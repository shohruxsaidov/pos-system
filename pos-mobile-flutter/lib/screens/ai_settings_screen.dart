import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';

/// Picks the Claude model + effort used by the assistant. The model list comes
/// from the backend (which proxies the Anthropic Models API) — nothing is
/// hardcoded here, so new models show up without an app release.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  static const _allEffortLevels = ['low', 'medium', 'high', 'xhigh', 'max'];

  List<Map<String, dynamic>> _models = [];
  List<String> _fallbackEffortLevels = _allEffortLevels;
  String? _model;
  String? _effort;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  Map<String, dynamic>? get _selected {
    for (final m in _models) {
      if (m['id'] == _model) return m;
    }
    return null;
  }

  /// Haiku 4.5, Sonnet 4.5 and Opus 4.1 reject the effort parameter.
  bool get _effortSupported => _selected?['effort_supported'] != false;

  List<String> get _effortLevels {
    final levels = (_selected?['effort_levels'] as List?)?.cast<String>();
    return levels != null && levels.isNotEmpty ? levels : _fallbackEffortLevels;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await apiService.get('/api/ai/status');
      final s = status.data as Map<String, dynamic>;
      _model = s['model'] as String?;
      _effort = s['effort'] as String?;
      final levels = (s['effort_levels'] as List?)?.cast<String>();
      if (levels != null && levels.isNotEmpty) _fallbackEffortLevels = levels;

      final res = await apiService.get('/api/ai/models');
      final data = res.data as Map<String, dynamic>;
      _models = (data['models'] as List? ?? []).cast<Map<String, dynamic>>();
      if (_models.isEmpty) {
        _error = 'Укажите Claude API ключ в настройках на десктопе.';
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_model == null) return;
    setState(() => _saving = true);
    try {
      await apiService.put('/api/settings', data: {
        'ai_model': _model,
        'ai_effort': _effort ?? 'low',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Настройки ассистента сохранены'),
          backgroundColor: AppColors.successBg,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.dangerBg,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('AI ассистент'),
        backgroundColor: AppColors.bgSidebar,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить список',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent1))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.warning, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],

                const _SectionLabel('МОДЕЛЬ'),
                ..._models.map((m) {
                  final id = m['id'] as String;
                  final selected = id == _model;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _model = id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.accent1.withValues(alpha: 0.12)
                              : AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.accent1
                                : AppColors.borderSubtle,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m['display_name'] as String? ?? id,
                                    style: TextStyle(
                                      color: selected
                                          ? AppColors.textAccent
                                          : AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    id,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle,
                                  color: AppColors.accent1, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),
                const _SectionLabel('ГЛУБИНА РАССУЖДЕНИЙ'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _effortLevels.map((level) {
                    final active = _effortSupported && level == _effort;
                    return GestureDetector(
                      onTap: _effortSupported
                          ? () => setState(() => _effort = level)
                          : null,
                      child: Opacity(
                        opacity: _effortSupported ? 1 : 0.4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.accent1.withValues(alpha: 0.15)
                                : AppColors.bgInput,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? AppColors.accent1
                                  : AppColors.borderDefault,
                            ),
                          ),
                          child: Text(
                            level,
                            style: TextStyle(
                              color: active
                                  ? AppColors.textAccent
                                  : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  _effortSupported
                      ? 'Выше — точнее и дороже. Для запросов к данным достаточно low.'
                      : 'Эта модель не поддерживает настройку глубины — параметр не отправляется.',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),

                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _saving || _model == null ? null : _save,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: (_saving || _model == null)
                          ? null
                          : AppColors.gradientHero,
                      color: (_saving || _model == null)
                          ? AppColors.bgSurface
                          : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Сохранить',
                            style: TextStyle(
                              color: _model == null
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
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

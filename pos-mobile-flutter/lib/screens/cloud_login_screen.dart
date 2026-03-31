import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/cloud_config.dart';
import '../services/cloud_api_service.dart';

class CloudLoginScreen extends StatefulWidget {
  const CloudLoginScreen({super.key});

  @override
  State<CloudLoginScreen> createState() => _CloudLoginScreenState();
}

class _CloudLoginScreenState extends State<CloudLoginScreen> {
  final _urlCtrl      = TextEditingController(text: CloudConfig.url ?? '');
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (url.isEmpty || password.isEmpty) {
      setState(() => _error = 'Введите URL и пароль');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // Temporarily set URL so cloudApiService can build the endpoint
      await CloudConfig.save(url: url, token: '');
      final data = await cloudApiService.post('/api/reports/login', body: { 'password': password });
      final token = data['token'] as String;
      await CloudConfig.save(url: url, token: token);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      await CloudConfig.clear();
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgSidebar,
        title: const Text('Подключение к облаку', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        iconTheme: const IconThemeData(color: AppColors.textMuted),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text('URL облачного сервера', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('https://cloud.example.com'),
              ),
              const SizedBox(height: 20),
              const Text('Пароль', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('••••••••'),
                onSubmitted: (_) => _connect(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent1,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: AppColors.accent1.withValues(alpha: 0.5),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Подключиться', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.bgInput,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.accent1, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

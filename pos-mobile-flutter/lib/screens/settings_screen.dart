import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_draft_provider.dart';
import 'offline_draft_screen.dart';
import 'qr_scanner_screen.dart';
import 'reports_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ApiConfig.baseUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result != null && mounted) {
      _urlCtrl.text = result;
      await _saveUrl();
    }
  }

  Future<void> _saveUrl() async {
    await ApiConfig.save(_urlCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Адрес сервера сохранён'),
          backgroundColor: AppColors.successBg,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isOnline = ref.watch(connectivityProvider);
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Настройки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info
          if (auth.user != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accentGlow,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        auth.user!.name[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.accent1,
                            fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.user!.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                      Text(auth.user!.role,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Server URL
          const Text('Адрес сервера',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                      hintText: 'http://192.168.1.x:3000'),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Сканировать QR-код',
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner,
                      color: AppColors.accent1),
                  onPressed: _scanQr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _saveUrl, child: const Text('Сохранить адрес')),
          const SizedBox(height: 32),

          // Draft sales (cashier / manager / admin)
          if (auth.user?.role == 'cashier' || auth.user?.role == 'manager' || auth.user?.role == 'admin') ...[
            Builder(builder: (context) {
              final pendingCount = ref.watch(offlineDraftProvider).pendingCount;
              return ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OfflineDraftScreen()),
                ),
                tileColor: AppColors.bgSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: !isOnline ? AppColors.warning.withValues(alpha: 0.4) : AppColors.borderSubtle,
                  ),
                ),
                leading: Icon(
                  Icons.edit_note,
                  color: !isOnline ? AppColors.warning : AppColors.accent1,
                ),
                title: const Text('Offline продажа',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: !isOnline
                    ? const Text('Офлайн — режим активен',
                        style: TextStyle(color: AppColors.warning, fontSize: 12))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pendingCount > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Reports (manager / admin only)
          if (auth.user?.role == 'manager' || auth.user?.role == 'admin') ...[
            ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              ),
              tileColor: AppColors.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.borderSubtle),
              ),
              leading: const Icon(Icons.bar_chart, color: AppColors.accent1),
              title: const Text('Отчёты',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
          ],

          // Logout
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.danger),
            label: const Text('Выйти',
                style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

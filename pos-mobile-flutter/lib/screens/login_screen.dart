import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_draft_provider.dart';
import 'qr_scanner_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _selectedUser;
  String _pin = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _scanQr() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result != null && mounted) {
      await ApiConfig.save(result);
      setState(() {
        _users = [];
        _error = null;
      });
      _loadUsers();
    }
  }

  Future<void> _showServerUrlDialog() async {
    final ctrl = TextEditingController(text: ApiConfig.baseUrl);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Адрес сервера',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppColors.textPrimary),
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.x:3000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiConfig.save(ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              // Reload users with new URL
              setState(() {
                _users = [];
                _error = null;
              });
              _loadUsers();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final auth = ref.read(authProvider.notifier);
      final users = await auth.fetchUsers();
      setState(() => _users = users);
    } catch (e) {
      setState(() => _error = 'Не удалось загрузить пользователей');
    }
  }

  void _onPinKey(String key) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += key;
      _error = null;
    });
    if (_pin.length == 4) _doLogin();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _doLogin() async {
    if (_selectedUser == null || _pin.length < 4) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .login(_selectedUser!['id'] as int, _pin);
      if (mounted) {
        setState(() => _loading = false);
        context.go('/sales');
      }
    } catch (_) {
      setState(() {
        _error = 'Неверный PIN';
        _pin = '';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.textMuted),
            tooltip: 'Сканировать QR-код',
            onPressed: _scanQr,
          ),
          IconButton(
            icon: const Icon(Icons.dns_outlined, color: AppColors.textMuted),
            tooltip: 'Адрес сервера',
            onPressed: _showServerUrlDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Title
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientHero,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.point_of_sale,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'POS Мобайл',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Выберите аккаунт',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showServerUrlDialog,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.dns_outlined,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          ApiConfig.baseUrl,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_selectedUser == null) ...[
                    // User list
                    if (_users.isEmpty && _error != null) ...[
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 14),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _error = null);
                          _loadUsers();
                        },
                        child: const Text('Повторить'),
                      ),
                    ] else if (_users.isEmpty)
                      const CircularProgressIndicator(
                          color: AppColors.accent1)
                    else
                      ..._users.map((user) => _UserCard(
                            user: user,
                            onTap: () =>
                                setState(() => _selectedUser = user),
                          )),

                    // Offline draft selling button
                    const SizedBox(height: 24),
                    _OfflineDraftButton(),
                  ] else ...[
                    // PIN entry
                    _buildPinEntry(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinEntry() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: AppColors.textSecondary),
              onPressed: () => setState(() {
                _selectedUser = null;
                _pin = '';
                _error = null;
              }),
            ),
            Expanded(
              child: Text(
                _selectedUser!['name'] as String,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 24),

        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            4,
            (i) => Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length
                    ? AppColors.accent1
                    : AppColors.bgInput,
                border: Border.all(
                  color: i < _pin.length
                      ? AppColors.accent1
                      : AppColors.borderDefault,
                ),
              ),
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 14)),
        ],

        const SizedBox(height: 32),

        // PIN pad
        if (_loading)
          const CircularProgressIndicator(color: AppColors.accent1)
        else
          _PinPad(onKey: _onPinKey, onDelete: _onDelete),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const _UserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentGlow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      (user['name'] as String)[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accent1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['name'] as String,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600)),
                      Text(user['role'] as String,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineDraftButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final pendingCount = ref.watch(offlineDraftProvider).pendingCount;

    return Column(
      children: [
        if (!isOnline)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, color: AppColors.warning, size: 14),
                SizedBox(width: 6),
                Text(
                  'Нет подключения',
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.push('/drafts'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textAccent,
              side: const BorderSide(color: AppColors.borderDefault),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_note_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('Офлайн продажи'),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PinPad extends StatelessWidget {
  final void Function(String) onKey;
  final VoidCallback onDelete;

  const _PinPad({required this.onKey, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_draft_provider.dart';
import 'sales_screen.dart';
import 'incoming_screen.dart';
import 'inventory_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _tab = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    if (user == null) return const SizedBox();

    final isOnline = ref.watch(connectivityProvider);

    // Connectivity transitions
    ref.listen<bool>(connectivityProvider, (prev, next) {
      final isSalesRole = user.role == 'cashier' || user.role == 'manager' || user.role == 'admin';

      if (next == false && prev == true) {
        // Going offline → immediately open draft selling screen for sales roles
        if (isSalesRole) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.push('/drafts');
          });
        }
      } else if (next == true && prev == false) {
        // Coming back online → auto-sync any pending drafts
        ref.read(offlineDraftProvider.notifier).syncAll();
      }
    });

    final tabs = _buildTabs(user.role);
    final screens = _buildScreens(user.role);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Column(
        children: [
          // Offline banner
          if (!isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: AppColors.warningBg,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: AppColors.warning, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Офлайн — режим черновиков',
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Screens
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgSidebar,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                ...tabs.asMap().entries.map((e) {
                final i = e.key;
                final tab = e.value;
                final active = _tab == i;
                final offlineDisabled = !isOnline && (tab['offlineDisabled'] as bool);
                final effectiveColor = offlineDisabled
                    ? AppColors.textMuted.withValues(alpha: 0.3)
                    : active
                        ? AppColors.accent1
                        : AppColors.textMuted;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (offlineDisabled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Недоступно офлайн'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      setState(() => _tab = i);
                      _pageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          active
                              ? tab['activeIcon'] as IconData
                              : tab['icon'] as IconData,
                          color: effectiveColor,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab['label'] as String,
                          style: TextStyle(
                            color: effectiveColor,
                            fontSize: 10,
                            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        // Active underline indicator
                        if (active && !offlineDisabled)
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 20,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: AppColors.gradientAccent,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
                // Settings / logout
                GestureDetector(
                  onTap: () => context.push('/settings'),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 48,
                    alignment: Alignment.center,
                    child: Builder(builder: (context) {
                      final pendingCount = ref.watch(offlineDraftProvider).pendingCount;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.settings_outlined,
                            color: AppColors.textMuted,
                            size: 22,
                          ),
                          if (pendingCount > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$pendingCount',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildTabs(String role) {
    final tabs = <Map<String, dynamic>>[];

    if (role == 'cashier' || role == 'manager' || role == 'admin') {
      tabs.add({
        'id': 'sales',
        'label': 'Продажи',
        'icon': Icons.shopping_cart_outlined,
        'activeIcon': Icons.shopping_cart,
        'offlineDisabled': true,
      });
    }

    tabs.add({
      'id': 'incoming',
      'label': 'Поступление',
      'icon': Icons.inbox_outlined,
      'activeIcon': Icons.inbox,
      'offlineDisabled': true,
    });

    tabs.add({
      'id': 'inventory',
      'label': 'Склад',
      'icon': Icons.inventory_2_outlined,
      'activeIcon': Icons.inventory_2,
      'offlineDisabled': true,
    });

    return tabs;
  }

  List<Widget> _buildScreens(String role) {
    final screens = <Widget>[];

    if (role == 'cashier' || role == 'manager' || role == 'admin') {
      screens.add(const SalesScreen());
    }

    screens.add(const IncomingScreen());
    screens.add(const InventoryScreen());

    return screens;
  }
}

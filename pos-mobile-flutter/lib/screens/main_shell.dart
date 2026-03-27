import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_draft_provider.dart';
import 'sales_screen.dart';
import 'incoming_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'offline_draft_screen.dart';

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
    final pendingCount = ref.watch(offlineDraftProvider).pendingCount;

    // Auto-switch to Drafts tab when connectivity drops
    ref.listen<bool>(connectivityProvider, (prev, next) {
      if (!next) {
        final tabs = _buildTabs(user.role);
        final draftsIdx = tabs.indexWhere((t) => t['id'] == 'drafts');
        if (draftsIdx >= 0 && _tab != draftsIdx) {
          setState(() => _tab = draftsIdx);
          _pageController.animateToPage(
            draftsIdx,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
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
              children: tabs.asMap().entries.map((e) {
                final i = e.key;
                final tab = e.value;
                final active = _tab == i;
                final offlineDisabled = !isOnline && (tab['offlineDisabled'] as bool);
                final isDraftsTab = tab['id'] == 'drafts';

                final effectiveColor = offlineDisabled
                    ? AppColors.textMuted.withOpacity(0.3)
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
                        // Icon with optional pending badge for Drafts tab
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              active
                                  ? tab['activeIcon'] as IconData
                                  : tab['icon'] as IconData,
                              color: effectiveColor,
                              size: 22,
                            ),
                            if (isDraftsTab && pendingCount > 0)
                              Positioned(
                                top: -4,
                                right: -8,
                                child: Container(
                                  width: 15,
                                  height: 15,
                                  decoration: const BoxDecoration(
                                    color: AppColors.warning,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      pendingCount > 9 ? '9+' : '$pendingCount',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
              }).toList(),
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
      'id': 'drafts',
      'label': 'Черновики',
      'icon': Icons.edit_note_outlined,
      'activeIcon': Icons.edit_note,
      'offlineDisabled': false,
    });

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

    if (role == 'manager' || role == 'admin') {
      tabs.add({
        'id': 'reports',
        'label': 'Отчёты',
        'icon': Icons.bar_chart_outlined,
        'activeIcon': Icons.bar_chart,
        'offlineDisabled': true,
      });
    }

    return tabs;
  }

  List<Widget> _buildScreens(String role) {
    final screens = <Widget>[];

    if (role == 'cashier' || role == 'manager' || role == 'admin') {
      screens.add(const SalesScreen());
    }

    screens.add(const OfflineDraftScreen());

    screens.add(const IncomingScreen());
    screens.add(const InventoryScreen());

    if (role == 'manager' || role == 'admin') {
      screens.add(const ReportsScreen());
    }

    return screens;
  }
}

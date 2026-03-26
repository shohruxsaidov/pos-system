import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import 'sales_screen.dart';
import 'incoming_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    if (user == null) return const SizedBox();

    // Build tabs based on role — same as pos-mobile bottom nav
    final tabs = _buildTabs(user.role);
    final screens = _buildScreens(user.role);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: screens.asMap().entries.map((e) {
          final isActive = _tab == e.key;
          return IgnorePointer(
            ignoring: !isActive,
            child: AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: e.value,
            ),
          );
        }).toList(),
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
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tab = i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          active
                              ? tab['activeIcon'] as IconData
                              : tab['icon'] as IconData,
                          color: active
                              ? AppColors.accent1
                              : AppColors.textMuted,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab['label'] as String,
                          style: TextStyle(
                            color: active
                                ? AppColors.accent1
                                : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        // Active underline indicator
                        if (active)
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
        'label': 'Sales',
        'icon': Icons.shopping_cart_outlined,
        'activeIcon': Icons.shopping_cart,
      });
    }

    tabs.add({
      'label': 'Incoming',
      'icon': Icons.inbox_outlined,
      'activeIcon': Icons.inbox,
    });

    tabs.add({
      'label': 'Inventory',
      'icon': Icons.inventory_2_outlined,
      'activeIcon': Icons.inventory_2,
    });

    if (role == 'manager' || role == 'admin') {
      tabs.add({
        'label': 'Reports',
        'icon': Icons.bar_chart_outlined,
        'activeIcon': Icons.bar_chart,
      });
    }

    return tabs;
  }

  List<Widget> _buildScreens(String role) {
    final screens = <Widget>[];

    if (role == 'cashier' || role == 'manager' || role == 'admin') {
      screens.add(const SalesScreen());
    }

    screens.add(const IncomingScreen());
    screens.add(const InventoryScreen());

    if (role == 'manager' || role == 'admin') {
      screens.add(const ReportsScreen());
    }

    return screens;
  }
}

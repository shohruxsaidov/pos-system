import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'cloud_reports_screen.dart';
import 'cloud_transactions_screen.dart';

class CloudShell extends StatefulWidget {
  const CloudShell({super.key});

  @override
  State<CloudShell> createState() => _CloudShellState();
}

class _CloudShellState extends State<CloudShell> {
  int _index = 0;

  static const _screens = <Widget>[
    CloudReportsScreen(),
    CloudTransactionsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: AppColors.bgSidebar,
        selectedItemColor: AppColors.accent1,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Дашборд',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Транзакции',
          ),
        ],
      ),
    );
  }
}

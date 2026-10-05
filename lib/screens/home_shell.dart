import 'package:flutter/material.dart';
import '../models/models.dart';
import 'dashboard_screen.dart';
import 'income_budget_screen.dart';
import 'manage_categories_screen.dart';
import 'module_screen.dart';

/// Bottom-nav shell: Dashboard, Income & Budget, Expenses, Funds,
/// Investments — one tab per module, same grouping as your spreadsheet's
/// tabs. Manage Categories is reachable from the app bar on any tab.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.userId});
  final String userId;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(userId: widget.userId),
      IncomeBudgetScreen(userId: widget.userId),
      ModuleScreen(userId: widget.userId, behavior: CategoryBehavior.expense, title: 'Expenses'),
      ModuleScreen(userId: widget.userId, behavior: CategoryBehavior.fund, title: 'Funds'),
      ModuleScreen(userId: widget.userId, behavior: CategoryBehavior.investment, title: 'Investments'),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Budget'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: 'Funds'),
          NavigationDestination(icon: Icon(Icons.trending_up_outlined), selectedIcon: Icon(Icons.trending_up), label: 'Invest'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_providers.dart';
import '../services/budget_engine.dart';
import '../widgets/budget_progress_bar.dart';
import 'add_entry_sheet.dart';
import 'manage_categories_screen.dart';

/// Mirrors Calc_Data + Dashboard: the headline numbers plus budget
/// progress for every item, grouped by category.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeProvider(userId));
    final notifier = ref.read(financeProvider(userId).notifier);

    if (finance.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mk = monthKey(DateTime.now());
    final calc = CalcData.compute(mk: mk, categories: finance.categories, items: finance.items, entries: finance.entries, budgets: finance.budgets);
    final totalIncome = notifier.totalIncome(mk);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddEntrySheet(context, userId),
        child: const Icon(Icons.add, size: 28),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.refreshFromLocal,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                color: AppColors.tealDeep,
                padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL INCOME THIS MONTH', style: TextStyle(fontSize: 11, letterSpacing: 1.4, color: Color(0xFFB7CFC9))),
                        IconButton(
                          icon: const Icon(Icons.category_outlined, color: Colors.white, size: 20),
                          tooltip: 'Manage Categories',
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageCategoriesScreen(userId: userId))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(formatRupee(totalIncome), style: AppTheme.serifDisplay(context, size: 32, color: Colors.white)),
                    const SizedBox(height: 14),
                    Row(children: [
                      _stat('Total Invested', calc.totalInvestment),
                      const SizedBox(width: 20),
                      _stat('Available Funds', calc.availableFunds),
                      const SizedBox(width: 20),
                      _stat('Total Available', calc.totalAvailable),
                    ]),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList(delegate: SliverChildListDelegate([
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('THIS MONTH AT A GLANCE', style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.gold)),
                        const SizedBox(height: 8),
                        _row('Expenses Spent', calc.expensesSpent),
                        _row('Expenses Left', calc.expensesLeft),
                        _row('Funds Spent', calc.fundsSpent),
                        _row('Funds Left', calc.fundsLeft),
                        _row('Monthly Investment', calc.monthlyInvestment),
                        _row('Available (not yet invested)', calc.availableInvestment),
                        const Divider(),
                        _row('Total Spent', calc.totalSpent, bold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final cat in finance.categories) _categorySection(cat, finance, mk),
              ])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, double value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8FB0A9))),
            Text(formatRupee(value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      );

  Widget _row(String label, double value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          Text(formatRupee(value), style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ]),
      );

  Widget _categorySection(Category cat, FinanceState finance, String mk) {
    final items = finance.itemsIn(cat.id);
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(cat.name.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.gold)),
              ),
              for (final item in items)
                BudgetProgressBar(
                  label: item.name,
                  color: cat.behavior == CategoryBehavior.investment ? AppColors.gold : AppColors.teal,
                  spent: BudgetEngine.statsFor(item: item, behavior: cat.behavior, mk: mk, entries: finance.entries, budgets: finance.budgets).actual,
                  target: () {
                    final s = BudgetEngine.statsFor(item: item, behavior: cat.behavior, mk: mk, entries: finance.entries, budgets: finance.budgets);
                    return cat.behavior == CategoryBehavior.fund ? s.budget + s.prevBalance : s.budget;
                  }(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

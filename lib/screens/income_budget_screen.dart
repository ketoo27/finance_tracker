import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_providers.dart';
import '../services/budget_engine.dart';
import 'manage_categories_screen.dart';

/// Mirrors `month_input`: income lines for the month, plus the budget
/// allocation table across every item, with a zero-based "remaining to
/// allocate" check (total_income − all budgets, same as the sheet's F9).
class IncomeBudgetScreen extends ConsumerStatefulWidget {
  const IncomeBudgetScreen({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<IncomeBudgetScreen> createState() => _IncomeBudgetScreenState();
}

class _IncomeBudgetScreenState extends ConsumerState<IncomeBudgetScreen> {
  late String mk;

  @override
  void initState() {
    super.initState();
    mk = monthKey(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(financeProvider(widget.userId).notifier).ensurePrevIncomeSuggested(mk);
    });
  }

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeProvider(widget.userId));
    final notifier = ref.read(financeProvider(widget.userId).notifier);
    final incomes = finance.incomes.where((e) => e.monthKey == mk).toList();
    final totalIncome = incomes.fold(0.0, (s, e) => s + e.amount);

    double allocated = 0, investmentBudget = 0;
    for (final cat in finance.categories) {
      for (final item in finance.itemsIn(cat.id)) {
        final b = BudgetEngine.budgetFor(finance.budgets, item.id, mk);
        if (cat.behavior == CategoryBehavior.investment) {
          investmentBudget += b;
        } else {
          allocated += b;
        }
      }
    }
    final remainingToAllocate = totalIncome - allocated - investmentBudget;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income & Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageCategoriesScreen(userId: widget.userId))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('INCOME THIS MONTH', style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.gold)),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      onPressed: () => _addIncomeDialog(notifier),
                    ),
                  ]),
                  for (final e in incomes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.name),
                      trailing: Text(formatRupee(e.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total Income', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(formatRupee(totalIncome), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ZERO-BASED CHECK', style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.gold)),
                  const SizedBox(height: 8),
                  _checkRow('Allocated (Needs+Wants+Funds)', allocated),
                  _checkRow('Allocated to Investments', investmentBudget),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Remaining to allocate', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      formatRupee(remainingToAllocate),
                      style: TextStyle(fontWeight: FontWeight.w600, color: remainingToAllocate < 0 ? AppColors.red : AppColors.green),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final cat in finance.categories) _categoryBudgetCard(cat, finance, notifier),
        ],
      ),
    );
  }

  Widget _checkRow(String label, double value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          Text(formatRupee(value), style: const TextStyle(fontSize: 13)),
        ]),
      );

  Widget _categoryBudgetCard(Category cat, FinanceState finance, FinanceNotifier notifier) {
    final items = finance.itemsIn(cat.id);
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cat.name.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.gold)),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  trailing: SizedBox(
                    width: 110,
                    child: TextFormField(
                      initialValue: BudgetEngine.budgetFor(finance.budgets, item.id, mk) == 0
                          ? ''
                          : BudgetEngine.budgetFor(finance.budgets, item.id, mk).toStringAsFixed(0),
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(prefixText: '₹ ', isDense: true),
                      onFieldSubmitted: (v) {
                        final amt = double.tryParse(v) ?? 0;
                        notifier.setBudget(item.id, mk, amt);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addIncomeDialog(FinanceNotifier notifier) async {
    final nameCtl = TextEditingController();
    final amtCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Income'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtl, decoration: const InputDecoration(hintText: 'e.g. Salary, Freelance')),
          const SizedBox(height: 8),
          TextField(controller: amtCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Amount')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && nameCtl.text.trim().isNotEmpty) {
      final amt = double.tryParse(amtCtl.text) ?? 0;
      await notifier.addIncome(mk, nameCtl.text.trim(), amt);
    }
  }
}

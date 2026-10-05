import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_providers.dart';
import '../services/budget_engine.dart';
import 'add_entry_sheet.dart';
import 'manage_categories_screen.dart';

/// One reusable screen that renders whichever tracker tab matches
/// [behavior] — Expense (Needs/Wants), Funds, or Investments — exactly
/// like the three separate tabs in your spreadsheet, but driven by
/// whatever categories/items of that behavior actually exist (including
/// ones you add later).
class ModuleScreen extends ConsumerWidget {
  const ModuleScreen({super.key, required this.userId, required this.behavior, required this.title});
  final String userId;
  final CategoryBehavior behavior;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeProvider(userId));
    final mk = monthKey(DateTime.now());
    final categories = finance.categories.where((c) => c.behavior == behavior).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageCategoriesScreen(userId: userId))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddEntrySheet(context, userId),
        child: const Icon(Icons.add, size: 28),
      ),
      body: categories.isEmpty
          ? Center(child: Text('No $title categories yet. Tap + to add one.', style: const TextStyle(color: AppColors.muted)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                for (final cat in categories) _categoryCard(cat, finance, mk),
              ],
            ),
    );
  }

  Widget _categoryCard(Category cat, FinanceState finance, String mk) {
    final items = finance.itemsIn(cat.id);
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(cat.name.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.gold)),
              ),
              for (final item in items) _itemRow(item, cat.behavior, finance, mk),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemRow(Item item, CategoryBehavior behavior, FinanceState finance, String mk) {
    final stats = BudgetEngine.statsFor(item: item, behavior: behavior, mk: mk, entries: finance.entries, budgets: finance.budgets);
    final entries = finance.entries.where((e) => e.itemId == item.id && monthKey(e.date) == mk).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: _summaryLine(behavior, stats),
      children: [
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No entries this month.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${DateFormat('d MMM').format(e.date)}${e.note.isNotEmpty ? ' · ${e.note}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                Text(formatRupee(e.amount), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _summaryLine(CategoryBehavior behavior, ItemStats s) {
    switch (behavior) {
      case CategoryBehavior.expense:
        final over = s.result < 0;
        return Text(
          '${formatRupee(s.actual)} spent of ${formatRupee(s.budget)} · ${over ? '${formatRupee(s.result)} over' : '${formatRupee(s.result)} left'}',
          style: TextStyle(fontSize: 12, color: over ? AppColors.red : AppColors.muted),
        );
      case CategoryBehavior.fund:
        return Text(
          '${formatRupee(s.budget + s.prevBalance)} available · ${formatRupee(s.actual)} spent · ${formatRupee(s.result)} remaining',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        );
      case CategoryBehavior.investment:
        return Text(
          '${formatRupee(s.actual)} invested of ${formatRupee(s.budget)} target · ${formatRupee(s.result)} total',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        );
    }
  }
}

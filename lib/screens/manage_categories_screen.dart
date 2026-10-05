import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_providers.dart';

/// Lets the user add new categories (any behavior) and items under them
/// any time — this is the direct fix for "preset categories" being a
/// dead end: presets are just the starting point, not a ceiling.
class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeProvider(userId));
    final notifier = ref.read(financeProvider(userId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _addCategoryDialog(context, notifier)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final cat in finance.categories)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [
                          Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.paperLine, borderRadius: BorderRadius.circular(10)),
                            child: Text(cat.behavior.db, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                          ),
                        ]),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () => _addItemDialog(context, notifier, cat.id),
                        ),
                      ]),
                    ),
                    for (final item in finance.itemsIn(cat.id))
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 6),
                        child: Text('• ${item.name}', style: const TextStyle(color: AppColors.muted)),
                      ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addCategoryDialog(BuildContext context, FinanceNotifier notifier) async {
    final nameCtl = TextEditingController();
    var behavior = CategoryBehavior.expense;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('New Category'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtl, autofocus: true, decoration: const InputDecoration(hintText: 'Category name')),
            const SizedBox(height: 12),
            SegmentedButton<CategoryBehavior>(
              segments: const [
                ButtonSegment(value: CategoryBehavior.expense, label: Text('Expense')),
                ButtonSegment(value: CategoryBehavior.fund, label: Text('Fund')),
                ButtonSegment(value: CategoryBehavior.investment, label: Text('Invest')),
              ],
              selected: {behavior},
              onSelectionChanged: (s) => setSt(() => behavior = s.first),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true && nameCtl.text.trim().isNotEmpty) {
      await notifier.addCategory(nameCtl.text.trim(), behavior);
    }
  }

  Future<void> _addItemDialog(BuildContext context, FinanceNotifier notifier, String categoryId) async {
    final nameCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Item'),
        content: TextField(controller: nameCtl, autofocus: true, decoration: const InputDecoration(hintText: 'Item name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && nameCtl.text.trim().isNotEmpty) {
      await notifier.addItem(categoryId, nameCtl.text.trim());
    }
  }
}

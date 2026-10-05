import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_providers.dart';

Future<void> showAddEntrySheet(BuildContext context, String userId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _AddEntrySheet(userId: userId),
  );
}

/// The fix for "new entry category button not working": this is now a
/// proper two-step picker — Category (preset chips, exactly like the
/// sheet's fixed Needs/Wants/Funds/Investments list, plus anything you've
/// added) then Item (filtered to that category, plus an inline "+ new
/// item" — matching the sheet's per-tab item dropdown exactly).
class _AddEntrySheet extends ConsumerStatefulWidget {
  const _AddEntrySheet({required this.userId});
  final String userId;

  @override
  ConsumerState<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<_AddEntrySheet> {
  String? _categoryId;
  String? _itemId;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    // Watching (not reading) the provider means a category/item added from
    // inside this very sheet shows up immediately in the chips below.
    final finance = ref.watch(financeProvider(widget.userId));
    final categories = finance.categories;
    final items = _categoryId == null ? <Item>[] : finance.itemsIn(_categoryId!);

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('New Entry', style: AppTheme.serifDisplay(context, size: 20)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('1. Category', style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.gold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final c in categories)
                ChoiceChip(
                  label: Text(c.name),
                  selected: _categoryId == c.id,
                  onSelected: (_) => setState(() { _categoryId = c.id; _itemId = null; }),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('New category'),
                onPressed: () => _promptNewCategory(context),
              ),
            ],
          ),
          if (_categoryId != null) ...[
            const SizedBox(height: 16),
            const Text('2. Item', style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.gold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                for (final i in items)
                  ChoiceChip(
                    label: Text(i.name),
                    selected: _itemId == i.id,
                    onSelected: (_) => setState(() => _itemId = i.id),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('New item'),
                  onPressed: () => _promptNewItem(context, _categoryId!),
                ),
              ],
            ),
          ],
          if (_itemId != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Amount'),
            ),
            const SizedBox(height: 10),
            TextField(controller: _note, decoration: const InputDecoration(hintText: 'Note (optional)')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: const Text('Save Entry'),
                onPressed: _saving ? null : _submit,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _promptNewCategory(BuildContext context) async {
    final nameCtl = TextEditingController();
    var behavior = CategoryBehavior.expense;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('New Category'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(hintText: 'Category name')),
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
            const SizedBox(height: 8),
            Text(
              switch (behavior) {
                CategoryBehavior.expense => 'Budget vs Spent vs Left — resets each month.',
                CategoryBehavior.fund => 'Envelope savings — unspent balance carries to next month.',
                CategoryBehavior.investment => 'Tracks cumulative invested value over time.',
              },
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (result == true && nameCtl.text.trim().isNotEmpty) {
      await ref.read(financeProvider(widget.userId).notifier).addCategory(nameCtl.text.trim(), behavior);
      setState(() {});
    }
  }

  Future<void> _promptNewItem(BuildContext context, String categoryId) async {
    final nameCtl = TextEditingController();
    final result = await showDialog<bool>(
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
    if (result == true && nameCtl.text.trim().isNotEmpty) {
      await ref.read(financeProvider(widget.userId).notifier).addItem(categoryId, nameCtl.text.trim());
      setState(() {});
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text);
    if (amount == null || amount <= 0 || _itemId == null) return;
    setState(() => _saving = true);
    await ref.read(financeProvider(widget.userId).notifier).addEntry(itemId: _itemId!, amount: amount, note: _note.text);
    if (mounted) Navigator.pop(context);
  }
}

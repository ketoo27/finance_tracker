import '../models/models.dart';

/// Stats for one Item in one month — the shape differs by the Category's
/// behavior, mirroring the three tracker tabs in the spreadsheet exactly.
class ItemStats {
  final double budget;      // Estimated Budget set for this item this month
  final double prevBalance; // carried in (0 for EXPENSE behavior)
  final double actual;      // Spent (expense/fund) or Invested (investment)
  final double result;      // Left (expense) / Remaining (fund) / Total Invested (investment)

  ItemStats({required this.budget, required this.prevBalance, required this.actual, required this.result});
}

/// Re-implements the spreadsheet's three tracker tabs + the month-to-month
/// carry rules you confirmed:
///  - EXPENSE items: no per-item carry. Leftover feeds the NEXT month's
///    income as a suggested "Previous month leftover" line instead.
///  - FUND items: Remaining (Available − Spent) carries forward as next
///    month's Prev Balance, per item.
///  - INVESTMENT items: Total Invested (Prev + Invested) always carries
///    forward cumulatively, per item — the budget target itself never adds
///    to the balance, only real transactions do.
class BudgetEngine {
  /// Sum of tracker entries for [itemId] within month [mk].
  static double actualInMonth(List<TrackerEntry> entries, String itemId, String mk) {
    return entries
        .where((e) => e.itemId == itemId && monthKey(e.date) == mk)
        .fold(0.0, (s, e) => s + e.amount);
  }

  static double budgetFor(List<ItemBudget> budgets, String itemId, String mk) {
    final match = budgets.where((b) => b.itemId == itemId && b.monthKey == mk);
    return match.isEmpty ? 0 : match.first.amount;
  }

  /// Recursively walks back month by month to compute an item's carried-in
  /// balance for FUND/INVESTMENT behavior items. EXPENSE items always
  /// start at 0 (no per-item carry).
  static double prevBalanceFor({
    required Item item,
    required CategoryBehavior behavior,
    required String mk,
    required List<TrackerEntry> entries,
    required List<ItemBudget> budgets,
  }) {
    if (behavior == CategoryBehavior.expense) return 0;
    final prevMk = prevMonthKey(mk);
    // Base case: nothing happened before this month for this item.
    final hasEarlierActivity = entries.any((e) => e.itemId == item.id && monthKey(e.date).compareTo(prevMk) <= 0) ||
        budgets.any((b) => b.itemId == item.id && b.monthKey.compareTo(prevMk) <= 0);
    if (!hasEarlierActivity) return 0;

    final earlierPrev = prevBalanceFor(item: item, behavior: behavior, mk: prevMk, entries: entries, budgets: budgets);
    final prevBudget = budgetFor(budgets, item.id, prevMk);
    final prevActual = actualInMonth(entries, item.id, prevMk);

    if (behavior == CategoryBehavior.fund) {
      final available = prevBudget + earlierPrev;
      return available - prevActual; // Remaining -> next month's Prev Balance
    } else {
      return earlierPrev + prevActual; // Total Invested -> next month's Prev Balance
    }
  }

  static ItemStats statsFor({
    required Item item,
    required CategoryBehavior behavior,
    required String mk,
    required List<TrackerEntry> entries,
    required List<ItemBudget> budgets,
  }) {
    final budget = budgetFor(budgets, item.id, mk);
    final actual = actualInMonth(entries, item.id, mk);
    final prev = prevBalanceFor(item: item, behavior: behavior, mk: mk, entries: entries, budgets: budgets);

    switch (behavior) {
      case CategoryBehavior.expense:
        return ItemStats(budget: budget, prevBalance: 0, actual: actual, result: budget - actual);
      case CategoryBehavior.fund:
        final available = budget + prev;
        return ItemStats(budget: budget, prevBalance: prev, actual: actual, result: available - actual);
      case CategoryBehavior.investment:
        return ItemStats(budget: budget, prevBalance: prev, actual: actual, result: prev + actual);
    }
  }

  /// The "Previous month leftover" income suggestion: sum of Left across
  /// all EXPENSE-behavior items for the given (now-ending) month. Shown as
  /// an editable suggested income line when the user opens a new month.
  static double suggestedPrevIncome({
    required String endingMk,
    required List<Category> categories,
    required List<Item> items,
    required List<TrackerEntry> entries,
    required List<ItemBudget> budgets,
  }) {
    final expenseCategoryIds = categories.where((c) => c.behavior == CategoryBehavior.expense).map((c) => c.id).toSet();
    final expenseItems = items.where((i) => expenseCategoryIds.contains(i.categoryId));
    double total = 0;
    for (final item in expenseItems) {
      final stats = statsFor(item: item, behavior: CategoryBehavior.expense, mk: endingMk, entries: entries, budgets: budgets);
      total += stats.result;
    }
    return total;
  }
}

/// Dashboard-level aggregates — mirrors the Calc_Data tab exactly.
class CalcData {
  final double totalInvestment;    // B1
  final double availableFunds;     // B2
  final double expensesSpent;      // B3
  final double fundsSpent;         // B4
  final double expensesLeft;       // B5
  final double fundsLeft;          // B6
  final double totalSpent;         // B7
  final double totalAvailable;     // B8
  final double monthlyInvestment;  // B9
  final double availableInvestment;// B10

  CalcData({
    required this.totalInvestment, required this.availableFunds, required this.expensesSpent,
    required this.fundsSpent, required this.expensesLeft, required this.fundsLeft,
    required this.totalSpent, required this.totalAvailable, required this.monthlyInvestment,
    required this.availableInvestment,
  });

  static CalcData compute({
    required String mk,
    required List<Category> categories,
    required List<Item> items,
    required List<TrackerEntry> entries,
    required List<ItemBudget> budgets,
  }) {
    double totalInvestment = 0, availableFunds = 0, expensesSpent = 0, fundsSpent = 0;
    double expensesLeft = 0, fundsLeft = 0, monthlyInvestment = 0, availableInvestment = 0;

    for (final cat in categories) {
      final catItems = items.where((i) => i.categoryId == cat.id);
      for (final item in catItems) {
        final s = BudgetEngine.statsFor(item: item, behavior: cat.behavior, mk: mk, entries: entries, budgets: budgets);
        switch (cat.behavior) {
          case CategoryBehavior.expense:
            expensesSpent += s.actual;
            expensesLeft += s.result;
            break;
          case CategoryBehavior.fund:
            fundsSpent += s.actual;
            fundsLeft += s.result;
            availableFunds += s.budget + s.prevBalance;
            break;
          case CategoryBehavior.investment:
            totalInvestment += s.result;
            monthlyInvestment += s.actual;
            availableInvestment += (s.budget - s.actual);
            break;
        }
      }
    }

    return CalcData(
      totalInvestment: totalInvestment,
      availableFunds: availableFunds,
      expensesSpent: expensesSpent,
      fundsSpent: fundsSpent,
      expensesLeft: expensesLeft,
      fundsLeft: fundsLeft,
      totalSpent: expensesSpent + fundsSpent,
      totalAvailable: expensesLeft + fundsLeft + availableInvestment,
      monthlyInvestment: monthlyInvestment,
      availableInvestment: availableInvestment,
    );
  }
}

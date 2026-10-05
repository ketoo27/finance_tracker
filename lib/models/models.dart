/// How a Category behaves for budgeting/rollover purposes — this is the
/// one thing that's fixed; everything else (which categories exist, which
/// items live under them) is fully user-extensible.
enum CategoryBehavior {
  /// Needs/Wants-style: Budget vs Spent vs Left. No per-item carry-forward —
  /// leftover feeds into next month's income as a "previous month leftover"
  /// line instead (see BudgetEngine.suggestedPrevIncome).
  expense,

  /// Envelope/sinking-fund style (e.g. "Trip fund", "Reserve"): Budget +
  /// PrevBalance = Available, minus Spent = Remaining. Remaining carries
  /// forward automatically as next month's PrevBalance for that same item.
  fund,

  /// Investment-vehicle style (e.g. "MF Eqy", "Gold"): PrevBalance + actual
  /// Invested = Total Invested, which always carries forward cumulatively.
  /// The Budget here is just a target to compare against, it never adds to
  /// the balance by itself — only real invested transactions do.
  investment,
}

extension CategoryBehaviorX on CategoryBehavior {
  String get db => switch (this) {
        CategoryBehavior.expense => 'EXPENSE',
        CategoryBehavior.fund => 'FUND',
        CategoryBehavior.investment => 'INVESTMENT',
      };
  static CategoryBehavior fromDb(String v) => switch (v) {
        'FUND' => CategoryBehavior.fund,
        'INVESTMENT' => CategoryBehavior.investment,
        _ => CategoryBehavior.expense,
      };
}

/// A top-level bucket — "Needs", "Wants", "Funds", "Investments" come
/// preset, but the user can add more of any behavior at any time.
class Category {
  final String id;
  final String userId;
  String name;
  CategoryBehavior behavior;
  final DateTime updatedAt;
  final bool dirty;

  Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.behavior,
    required this.updatedAt,
    this.dirty = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'user_id': userId, 'name': name, 'behavior': behavior.db,
        'updated_at': updatedAt.toIso8601String(), 'dirty': dirty ? 1 : 0,
      };

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        name: m['name'] as String,
        behavior: CategoryBehaviorX.fromDb(m['behavior'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        dirty: (m['dirty'] ?? 0) == 1,
      );

  Map<String, dynamic> toSupabase() => {
        'id': id, 'user_id': userId, 'name': name, 'behavior': behavior.db,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// An actual budget line item living under a Category — "Fuel", "Trip
/// fund", "MF Eqy", etc. This is what the Add Entry flow's second step
/// picks from, and what every transaction is logged against.
class Item {
  final String id;
  final String userId;
  final String categoryId;
  String name;
  final DateTime updatedAt;
  final bool dirty;

  Item({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.name,
    required this.updatedAt,
    this.dirty = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'user_id': userId, 'category_id': categoryId, 'name': name,
        'updated_at': updatedAt.toIso8601String(), 'dirty': dirty ? 1 : 0,
      };

  factory Item.fromMap(Map<String, dynamic> m) => Item(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        categoryId: m['category_id'] as String,
        name: m['name'] as String,
        updatedAt: DateTime.parse(m['updated_at'] as String),
        dirty: (m['dirty'] ?? 0) == 1,
      );

  Map<String, dynamic> toSupabase() => {
        'id': id, 'user_id': userId, 'category_id': categoryId, 'name': name,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// One logged transaction against an Item — this is the single input type
/// that powers every tracker tab (no separate "fund account" concept).
class TrackerEntry {
  final String id;
  final String userId;
  final String itemId;
  final double amount;
  final DateTime date;
  final String note;
  final DateTime updatedAt;
  final bool dirty;

  TrackerEntry({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.amount,
    required this.date,
    required this.note,
    required this.updatedAt,
    this.dirty = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'user_id': userId, 'item_id': itemId, 'amount': amount,
        'date': date.toIso8601String(), 'note': note,
        'updated_at': updatedAt.toIso8601String(), 'dirty': dirty ? 1 : 0,
      };

  factory TrackerEntry.fromMap(Map<String, dynamic> m) => TrackerEntry(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        itemId: m['item_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        date: DateTime.parse(m['date'] as String),
        note: (m['note'] ?? '') as String,
        updatedAt: DateTime.parse(m['updated_at'] as String),
        dirty: (m['dirty'] ?? 0) == 1,
      );

  Map<String, dynamic> toSupabase() => {
        'id': id, 'user_id': userId, 'item_id': itemId, 'amount': amount,
        'date': date.toIso8601String(), 'note': note,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// The Estimated Budget assigned to one Item for one month — set during
/// monthly planning, compared against actual Spent/Invested.
class ItemBudget {
  final String id;
  final String userId;
  final String itemId;
  final String monthKey; // 'YYYY-MM'
  final double amount;
  final DateTime updatedAt;
  final bool dirty;

  ItemBudget({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.monthKey,
    required this.amount,
    required this.updatedAt,
    this.dirty = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'user_id': userId, 'item_id': itemId, 'month_key': monthKey,
        'amount': amount, 'updated_at': updatedAt.toIso8601String(), 'dirty': dirty ? 1 : 0,
      };

  factory ItemBudget.fromMap(Map<String, dynamic> m) => ItemBudget(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        itemId: m['item_id'] as String,
        monthKey: m['month_key'] as String,
        amount: (m['amount'] as num).toDouble(),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        dirty: (m['dirty'] ?? 0) == 1,
      );

  Map<String, dynamic> toSupabase() => {
        'id': id, 'user_id': userId, 'item_id': itemId, 'month_key': monthKey,
        'amount': amount, 'updated_at': updatedAt.toIso8601String(),
      };
}

/// One income line for a given month — "Salary", "Freelance", or the
/// auto-suggested "Previous month leftover" line.
class IncomeEntry {
  final String id;
  final String userId;
  final String monthKey;
  String name;
  double amount;
  final DateTime updatedAt;
  final bool dirty;

  IncomeEntry({
    required this.id,
    required this.userId,
    required this.monthKey,
    required this.name,
    required this.amount,
    required this.updatedAt,
    this.dirty = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'user_id': userId, 'month_key': monthKey, 'name': name,
        'amount': amount, 'updated_at': updatedAt.toIso8601String(), 'dirty': dirty ? 1 : 0,
      };

  factory IncomeEntry.fromMap(Map<String, dynamic> m) => IncomeEntry(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        monthKey: m['month_key'] as String,
        name: m['name'] as String,
        amount: (m['amount'] as num).toDouble(),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        dirty: (m['dirty'] ?? 0) == 1,
      );

  Map<String, dynamic> toSupabase() => {
        'id': id, 'user_id': userId, 'month_key': monthKey, 'name': name,
        'amount': amount, 'updated_at': updatedAt.toIso8601String(),
      };
}

String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

String prevMonthKey(String mk) {
  final parts = mk.split('-');
  final d = DateTime(int.parse(parts[0]), int.parse(parts[1]) - 1, 1);
  return monthKey(d);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../services/budget_engine.dart';
import '../services/sync_service.dart';

const _uuid = Uuid();

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
final authServiceProvider = Provider((ref) => AuthService(ref.read(supabaseProvider)));
final syncServiceProvider = Provider((ref) => SyncService(ref.read(supabaseProvider)));

final authStateProvider = StreamProvider<String?>((ref) {
  return ref.read(authServiceProvider).onAuthStateChange.map((s) => s.session?.user.id);
});

/// Preset Category/Item seed, taken directly from your spreadsheet's Input
/// tab. Created once for a brand-new user; fully editable/extendable after.
const presetSeed = {
  'Needs': {'behavior': CategoryBehavior.expense, 'items': ['Fuel', 'Grooming', 'Diet', 'Personal Care']},
  'Wants': {'behavior': CategoryBehavior.expense, 'items': ['Weekends/Dining', 'Daily Spending', 'Online Shopping']},
  'Funds': {'behavior': CategoryBehavior.fund, 'items': ['Mobile recharge fund', 'Gym', 'Gadget Fund', 'Clothing & Apparel Fund', 'Gifting & Festival Fund', 'Trip fund', 'Reserve']},
  'Investments': {'behavior': CategoryBehavior.investment, 'items': ['MF Eqy', 'MF Debt', 'Gold', 'Silver', 'FD 1y']},
};

class FinanceState {
  final List<Category> categories;
  final List<Item> items;
  final List<TrackerEntry> entries;
  final List<ItemBudget> budgets;
  final List<IncomeEntry> incomes;
  final bool loading;

  const FinanceState({
    this.categories = const [], this.items = const [], this.entries = const [],
    this.budgets = const [], this.incomes = const [], this.loading = true,
  });

  FinanceState copyWith({
    List<Category>? categories, List<Item>? items, List<TrackerEntry>? entries,
    List<ItemBudget>? budgets, List<IncomeEntry>? incomes, bool? loading,
  }) => FinanceState(
        categories: categories ?? this.categories,
        items: items ?? this.items,
        entries: entries ?? this.entries,
        budgets: budgets ?? this.budgets,
        incomes: incomes ?? this.incomes,
        loading: loading ?? this.loading,
      );

  Category? categoryOf(String itemId) {
    final item = items.where((i) => i.id == itemId);
    if (item.isEmpty) return null;
    final cat = categories.where((c) => c.id == item.first.categoryId);
    return cat.isEmpty ? null : cat.first;
  }

  List<Item> itemsIn(String categoryId) => items.where((i) => i.categoryId == categoryId).toList();
}

class FinanceNotifier extends StateNotifier<FinanceState> {
  FinanceNotifier(this._userId, this._sync) : super(const FinanceState()) {
    _init();
  }

  final String _userId;
  final SyncService _sync;
  final _local = LocalDb.instance;

  Future<void> _init() async {
    await refreshFromLocal();
    if (state.categories.isEmpty) {
      await _seedPresets();
      await refreshFromLocal();
    }
    _sync.start(_userId);
    Future.delayed(const Duration(seconds: 3), refreshFromLocal);
  }

  Future<void> _seedPresets() async {
    for (final entry in presetSeed.entries) {
      final behavior = entry.value['behavior'] as CategoryBehavior;
      final itemNames = entry.value['items'] as List<String>;
      final category = Category(id: _uuid.v4(), userId: _userId, name: entry.key, behavior: behavior, updatedAt: DateTime.now(), dirty: true);
      await _local.upsertCategory(category);
      for (final name in itemNames) {
        await _local.upsertItem(Item(id: _uuid.v4(), userId: _userId, categoryId: category.id, name: name, updatedAt: DateTime.now(), dirty: true));
      }
    }
  }

  Future<void> refreshFromLocal() async {
    state = state.copyWith(
      categories: await _local.getCategories(_userId),
      items: await _local.getItems(_userId),
      entries: await _local.getEntries(_userId),
      budgets: await _local.getBudgets(_userId),
      incomes: await _local.getIncomes(_userId),
      loading: false,
    );
  }

  Future<void> addCategory(String name, CategoryBehavior behavior) async {
    await _local.upsertCategory(Category(id: _uuid.v4(), userId: _userId, name: name, behavior: behavior, updatedAt: DateTime.now(), dirty: true));
    await refreshFromLocal();
    _sync.syncAll(_userId);
  }

  Future<void> addItem(String categoryId, String name) async {
    await _local.upsertItem(Item(id: _uuid.v4(), userId: _userId, categoryId: categoryId, name: name, updatedAt: DateTime.now(), dirty: true));
    await refreshFromLocal();
    _sync.syncAll(_userId);
  }

  Future<void> addEntry({required String itemId, required double amount, String note = '', DateTime? date}) async {
    final now = DateTime.now();
    await _local.upsertEntry(TrackerEntry(
      id: _uuid.v4(), userId: _userId, itemId: itemId, amount: amount,
      date: date ?? now, note: note, updatedAt: now, dirty: true,
    ));
    await refreshFromLocal();
    _sync.syncAll(_userId);
  }

  Future<void> setBudget(String itemId, String monthKey, double amount) async {
    final existing = state.budgets.where((b) => b.itemId == itemId && b.monthKey == monthKey);
    final id = existing.isEmpty ? _uuid.v4() : existing.first.id;
    await _local.upsertBudget(ItemBudget(id: id, userId: _userId, itemId: itemId, monthKey: monthKey, amount: amount, updatedAt: DateTime.now(), dirty: true));
    await refreshFromLocal();
    _sync.syncAll(_userId);
  }

  Future<void> addIncome(String monthKey, String name, double amount) async {
    await _local.upsertIncome(IncomeEntry(id: _uuid.v4(), userId: _userId, monthKey: monthKey, name: name, amount: amount, updatedAt: DateTime.now(), dirty: true));
    await refreshFromLocal();
    _sync.syncAll(_userId);
  }

  /// Call when the user opens a month that has no income lines yet — adds
  /// the suggested "Previous month leftover" line (editable afterwards)
  /// per the carry-forward rule you confirmed.
  Future<void> ensurePrevIncomeSuggested(String mk) async {
    final alreadyHasIncome = state.incomes.any((e) => e.monthKey == mk);
    if (alreadyHasIncome) return;
    final suggested = BudgetEngine.suggestedPrevIncome(
      endingMk: prevMonthKey(mk),
      categories: state.categories,
      items: state.items,
      entries: state.entries,
      budgets: state.budgets,
    );
    if (suggested != 0) {
      await addIncome(mk, 'Previous month leftover', suggested);
    }
  }

  double totalIncome(String mk) =>
      state.incomes.where((e) => e.monthKey == mk).fold(0.0, (s, e) => s + e.amount);
}

final financeProvider = StateNotifierProvider.family<FinanceNotifier, FinanceState, String>((ref, userId) {
  return FinanceNotifier(userId, ref.read(syncServiceProvider));
});

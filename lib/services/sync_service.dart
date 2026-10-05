import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'local_db.dart';

/// Offline-first cloud sync: pushes dirty local rows to Supabase whenever
/// online, pulls remote changes (last-write-wins by `updated_at`).
class SyncService {
  SyncService(this._supabase);
  final SupabaseClient _supabase;
  final _local = LocalDb.instance;

  StreamSubscription? _connSub;
  Timer? _periodic;

  void start(String userId) {
    syncAll(userId);
    _connSub = Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) syncAll(userId);
    });
    _periodic = Timer.periodic(const Duration(minutes: 2), (_) => syncAll(userId));
  }

  void stop() {
    _connSub?.cancel();
    _periodic?.cancel();
  }

  Future<bool> _isOnline() async =>
      !(await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);

  Future<void> syncAll(String userId) async {
    if (!await _isOnline()) return;
    try {
      await _pushCategories(userId);
      await _pushItems(userId);
      await _pushEntries(userId);
      await _pushBudgets(userId);
      await _pushIncomes(userId);
      await _pullCategories(userId);
      await _pullItems(userId);
      await _pullEntries(userId);
      await _pullBudgets(userId);
      await _pullIncomes(userId);
    } catch (_) {
      // Next timer tick or connectivity event retries.
    }
  }

  Future<void> _pushCategories(String userId) async {
    for (final c in await _local.getDirtyCategories(userId)) {
      await _supabase.from('categories').upsert(c.toSupabase());
      await _local.markClean('categories', c.id);
    }
  }

  Future<void> _pushItems(String userId) async {
    for (final i in await _local.getDirtyItems(userId)) {
      await _supabase.from('items').upsert(i.toSupabase());
      await _local.markClean('items', i.id);
    }
  }

  Future<void> _pushEntries(String userId) async {
    for (final t in await _local.getDirtyEntries(userId)) {
      await _supabase.from('tracker_entries').upsert(t.toSupabase());
      await _local.markClean('tracker_entries', t.id);
    }
  }

  Future<void> _pushBudgets(String userId) async {
    for (final b in await _local.getDirtyBudgets(userId)) {
      await _supabase.from('item_budgets').upsert(b.toSupabase());
      await _local.markClean('item_budgets', b.id);
    }
  }

  Future<void> _pushIncomes(String userId) async {
    for (final e in await _local.getDirtyIncomes(userId)) {
      await _supabase.from('income_entries').upsert(e.toSupabase());
      await _local.markClean('income_entries', e.id);
    }
  }

  Future<void> _pullCategories(String userId) async {
    final remote = await _supabase.from('categories').select().eq('user_id', userId);
    final local = {for (final c in await _local.getCategories(userId)) c.id: c};
    for (final row in remote) {
      final r = Category.fromMap({...row, 'dirty': 0});
      final e = local[r.id];
      if ((e == null || r.updatedAt.isAfter(e.updatedAt)) && (e == null || !e.dirty)) {
        await _local.upsertCategory(r);
      }
    }
  }

  Future<void> _pullItems(String userId) async {
    final remote = await _supabase.from('items').select().eq('user_id', userId);
    final local = {for (final i in await _local.getItems(userId)) i.id: i};
    for (final row in remote) {
      final r = Item.fromMap({...row, 'dirty': 0});
      final e = local[r.id];
      if ((e == null || r.updatedAt.isAfter(e.updatedAt)) && (e == null || !e.dirty)) {
        await _local.upsertItem(r);
      }
    }
  }

  Future<void> _pullEntries(String userId) async {
    final remote = await _supabase.from('tracker_entries').select().eq('user_id', userId);
    final local = {for (final t in await _local.getEntries(userId)) t.id: t};
    for (final row in remote) {
      final r = TrackerEntry.fromMap({...row, 'dirty': 0});
      final e = local[r.id];
      if ((e == null || r.updatedAt.isAfter(e.updatedAt)) && (e == null || !e.dirty)) {
        await _local.upsertEntry(r);
      }
    }
  }

  Future<void> _pullBudgets(String userId) async {
    final remote = await _supabase.from('item_budgets').select().eq('user_id', userId);
    final local = {for (final b in await _local.getBudgets(userId)) b.id: b};
    for (final row in remote) {
      final r = ItemBudget.fromMap({...row, 'dirty': 0});
      final e = local[r.id];
      if ((e == null || r.updatedAt.isAfter(e.updatedAt)) && (e == null || !e.dirty)) {
        await _local.upsertBudget(r);
      }
    }
  }

  Future<void> _pullIncomes(String userId) async {
    final remote = await _supabase.from('income_entries').select().eq('user_id', userId);
    final local = {for (final e in await _local.getIncomes(userId)) e.id: e};
    for (final row in remote) {
      final r = IncomeEntry.fromMap({...row, 'dirty': 0});
      final e = local[r.id];
      if ((e == null || r.updatedAt.isAfter(e.updatedAt)) && (e == null || !e.dirty)) {
        await _local.upsertIncome(r);
      }
    }
  }
}

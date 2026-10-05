import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

/// Local SQLite cache — single source of truth for the UI, so the app
/// works fully offline. `dirty` rows still need pushing to Supabase.
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();
  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'finance_tracker.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY, user_id TEXT NOT NULL, name TEXT NOT NULL,
            behavior TEXT NOT NULL, updated_at TEXT NOT NULL, dirty INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE items (
            id TEXT PRIMARY KEY, user_id TEXT NOT NULL, category_id TEXT NOT NULL,
            name TEXT NOT NULL, updated_at TEXT NOT NULL, dirty INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE tracker_entries (
            id TEXT PRIMARY KEY, user_id TEXT NOT NULL, item_id TEXT NOT NULL,
            amount REAL NOT NULL, date TEXT NOT NULL, note TEXT,
            updated_at TEXT NOT NULL, dirty INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE item_budgets (
            id TEXT PRIMARY KEY, user_id TEXT NOT NULL, item_id TEXT NOT NULL,
            month_key TEXT NOT NULL, amount REAL NOT NULL,
            updated_at TEXT NOT NULL, dirty INTEGER NOT NULL DEFAULT 1,
            UNIQUE(item_id, month_key)
          )
        ''');
        await db.execute('''
          CREATE TABLE income_entries (
            id TEXT PRIMARY KEY, user_id TEXT NOT NULL, month_key TEXT NOT NULL,
            name TEXT NOT NULL, amount REAL NOT NULL,
            updated_at TEXT NOT NULL, dirty INTEGER NOT NULL DEFAULT 1
          )
        ''');
      },
    );
  }

  Future<void> upsertCategory(Category c) async =>
      (await db).insert('categories', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<Category>> getCategories(String userId) async =>
      (await (await db).query('categories', where: 'user_id = ?', whereArgs: [userId])).map(Category.fromMap).toList();

  Future<void> upsertItem(Item i) async =>
      (await db).insert('items', i.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<Item>> getItems(String userId) async =>
      (await (await db).query('items', where: 'user_id = ?', whereArgs: [userId])).map(Item.fromMap).toList();

  Future<void> upsertEntry(TrackerEntry t) async =>
      (await db).insert('tracker_entries', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<TrackerEntry>> getEntries(String userId) async =>
      (await (await db).query('tracker_entries', where: 'user_id = ?', whereArgs: [userId], orderBy: 'date DESC'))
          .map(TrackerEntry.fromMap).toList();

  Future<void> upsertBudget(ItemBudget b) async =>
      (await db).insert('item_budgets', b.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<ItemBudget>> getBudgets(String userId) async =>
      (await (await db).query('item_budgets', where: 'user_id = ?', whereArgs: [userId])).map(ItemBudget.fromMap).toList();

  Future<void> upsertIncome(IncomeEntry e) async =>
      (await db).insert('income_entries', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<IncomeEntry>> getIncomes(String userId) async =>
      (await (await db).query('income_entries', where: 'user_id = ?', whereArgs: [userId])).map(IncomeEntry.fromMap).toList();

  // ---- Sync helpers ----
  Future<List<Map<String, dynamic>>> _dirty(String table, String userId) async =>
      (await db).query(table, where: 'user_id = ? AND dirty = 1', whereArgs: [userId]);

  Future<List<Category>> getDirtyCategories(String userId) async => (await _dirty('categories', userId)).map(Category.fromMap).toList();
  Future<List<Item>> getDirtyItems(String userId) async => (await _dirty('items', userId)).map(Item.fromMap).toList();
  Future<List<TrackerEntry>> getDirtyEntries(String userId) async => (await _dirty('tracker_entries', userId)).map(TrackerEntry.fromMap).toList();
  Future<List<ItemBudget>> getDirtyBudgets(String userId) async => (await _dirty('item_budgets', userId)).map(ItemBudget.fromMap).toList();
  Future<List<IncomeEntry>> getDirtyIncomes(String userId) async => (await _dirty('income_entries', userId)).map(IncomeEntry.fromMap).toList();

  Future<void> markClean(String table, String id) async =>
      (await db).update(table, {'dirty': 0}, where: 'id = ?', whereArgs: [id]);
}

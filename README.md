# Ledger — Personal Finance Tracker (Flutter + Supabase)

Envelope budgeting + investment tracking, rebuilt directly from your
Google Sheet's structure. Offline-first (sqflite cache), cloud-synced
(Supabase), with a GitHub Actions workflow that builds the APK for you.

## What changed from the previous version

The original build modeled "Funds" as bank accounts (HDFC, Cash Wallet).
Your sheet does something different and better: there are no bank
accounts at all — just **Categories** (Needs, Wants, Funds, Investments)
containing **Items** (Fuel, Trip fund, MF Eqy, etc.), with one unified
entry log per item. This rebuild matches that exactly:

| Your sheet tab | App equivalent | Carry-forward rule |
|---|---|---|
| `Input` (Categories + Items master list) | Manage Categories screen — presets seeded on first run, fully editable/extendable | — |
| `month_input` | Income & Budget tab | "Previous month leftover" income line is suggested automatically from last month's Needs+Wants leftover |
| `expense tracker` (Needs+Wants) | Expenses tab | No per-item carry — leftover feeds next month's income instead |
| `Funds tracker` | Funds tab | Remaining carries forward per-item as next month's Prev Balance |
| `investment tracker` | Investments tab | Total Invested carries forward cumulatively per-item |
| `Calc_Data` + `Dashboard` | Dashboard tab | Same aggregate numbers (Total Investment, Available Funds, Expenses/Funds Spent & Left, etc.) |

**The bug you reported is fixed**: Add Entry is now a proper two-step
picker — Category chips (your 4 presets, or any you've added) → Item
chips filtered to that category, each with an inline "+ new" option.
Categories themselves are no longer fixed: Manage Categories (the
category icon on any screen's app bar) lets you add a 5th, 6th, etc.,
each tagged as Expense/Fund/Investment so the app knows how to carry it
forward.

No cron function is needed anymore (removed `rollover_function.sql`
from the previous version) — balances are computed live from the raw
entry/budget history every time, so there's nothing to drift or
re-sync.

## Setup — same as before

1. `flutter create --org com.yourname --project-name finance_tracker .` to generate `android/`
2. Merge `android/AndroidManifest.additions.xml`'s internet permission into the generated manifest
3. `flutter pub get`
4. Run `supabase/schema.sql` in your Supabase project's SQL Editor (5 tables: `categories`, `items`, `tracker_entries`, `item_budgets`, `income_entries`, all RLS-scoped to `auth.uid()`)
5. Push to GitHub, add `SUPABASE_URL` / `SUPABASE_ANON_KEY` repo secrets, let `.github/workflows/build-apk.yml` build the APK — see the Actions tab, download from the finished run's Artifacts section

## How the pieces fit together

| Requirement | Where it lives |
|---|---|
| Offline cache | `lib/services/local_db.dart` |
| Cloud sync | `lib/services/sync_service.dart` |
| Behavior-aware budgeting (Expense/Fund/Investment math) | `lib/services/budget_engine.dart` — `BudgetEngine` for per-item stats, `CalcData` for dashboard aggregates |
| Add Entry (category→item picker, the reported bug) | `lib/screens/add_entry_sheet.dart` |
| Income + budget allocation + zero-based check | `lib/screens/income_budget_screen.dart` |
| Expense/Funds/Investment tabs (one reusable screen) | `lib/screens/module_screen.dart` |
| Category/Item management | `lib/screens/manage_categories_screen.dart` |
| Bottom navigation shell | `lib/screens/home_shell.dart` |

## Known gaps

- Signing out isn't wired up yet (no settings screen) — low priority since there's only one account per device in practice
- Budget allocation editing is per-item inline fields; a dedicated "copy last month's budgets" button would save re-typing every month — flag if you want this added
- Sync conflict handling is last-write-wins — fine for 1–2 devices on one account

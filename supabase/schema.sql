-- ============================================================
-- Personal Finance Tracker — Supabase schema (envelope budgeting model)
-- Run this in Supabase Studio -> SQL Editor
-- ============================================================

create extension if not exists "uuid-ossp";

create table if not exists categories (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  behavior text not null check (behavior in ('EXPENSE', 'FUND', 'INVESTMENT')),
  updated_at timestamptz not null default now()
);

create table if not exists items (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid not null references categories(id) on delete cascade,
  name text not null,
  updated_at timestamptz not null default now()
);

create table if not exists tracker_entries (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null references items(id) on delete restrict,
  amount numeric(14,2) not null check (amount > 0),
  date timestamptz not null default now(),
  note text default '',
  updated_at timestamptz not null default now()
);

create table if not exists item_budgets (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null references items(id) on delete cascade,
  month_key text not null, -- 'YYYY-MM'
  amount numeric(14,2) not null default 0,
  updated_at timestamptz not null default now(),
  unique (item_id, month_key)
);

create table if not exists income_entries (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  month_key text not null,
  name text not null,
  amount numeric(14,2) not null default 0,
  updated_at timestamptz not null default now()
);

create index if not exists idx_items_category on items(category_id);
create index if not exists idx_entries_item_date on tracker_entries(item_id, date desc);
create index if not exists idx_budgets_item_month on item_budgets(item_id, month_key);
create index if not exists idx_income_month on income_entries(user_id, month_key);

-- ============================================================
-- Row Level Security — every table scoped to auth.uid()
-- ============================================================

alter table categories enable row level security;
alter table items enable row level security;
alter table tracker_entries enable row level security;
alter table item_budgets enable row level security;
alter table income_entries enable row level security;

create policy "Users manage their own categories" on categories for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage their own items" on items for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage their own tracker entries" on tracker_entries for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage their own item budgets" on item_budgets for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage their own income entries" on income_entries for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
-- Realtime
-- ============================================================
alter publication supabase_realtime add table categories;
alter publication supabase_realtime add table items;
alter publication supabase_realtime add table tracker_entries;
alter publication supabase_realtime add table item_budgets;
alter publication supabase_realtime add table income_entries;

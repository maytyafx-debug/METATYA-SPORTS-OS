create table if not exists public.data_bank (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('price','news','snapshot')),
  key text not null check (length(key) <= 80),
  payload jsonb not null,
  fetched_at timestamptz not null default now()
);
create index if not exists data_bank_kind_key_idx on public.data_bank (kind, key, fetched_at desc);
alter table public.data_bank enable row level security;
revoke all on public.data_bank from anon, authenticated, public;

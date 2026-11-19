create table if not exists public.orders (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  name text not null check (char_length(name) between 2 and 60),
  contact text not null check (char_length(contact) between 3 and 120),
  service text not null check (service in ('risk','bourse','fit','mind','biz')),
  note text not null default '' check (char_length(note) <= 500),
  source text not null default 'site' check (char_length(source) <= 60),
  consent boolean not null check (consent = true),
  status text not null default 'new'
);
alter table public.orders enable row level security;
create policy "anon can insert orders with consent" on public.orders for insert to anon with check (consent = true);

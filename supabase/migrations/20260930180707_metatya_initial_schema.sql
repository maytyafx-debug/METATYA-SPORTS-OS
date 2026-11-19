create table if not exists public.content_drafts (
  id uuid primary key default gen_random_uuid(),
  topic text, headline text, body text,
  status text default 'pending',
  created_at timestamptz default now()
);
create table if not exists public.finance_ledger (
  id uuid primary key default gen_random_uuid(),
  type text, amount numeric, currency text, usd_equivalent numeric,
  category text, note text,
  created_at timestamptz default now()
);
create table if not exists public.monetization_opportunities (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid, topic text, headline text, channel text,
  status text default 'pending_admin_review',
  created_at timestamptz default now()
);
create table if not exists public.needs_offers (
  id uuid primary key default gen_random_uuid(),
  area text, title text, description text, monetization text, link text,
  status text default 'pending',
  created_at timestamptz default now()
);

alter table public.content_drafts enable row level security;
alter table public.finance_ledger enable row level security;
alter table public.monetization_opportunities enable row level security;
alter table public.needs_offers enable row level security;

-- سایت (کلید anon) فقط محتوای منتشرشده را می‌تواند بخواند
create policy "public read published drafts" on public.content_drafts
  for select to anon using (status = 'published');
create policy "public read published needs" on public.needs_offers
  for select to anon using (status = 'published');
-- finance_ledger و monetization_opportunities عمداً هیچ policy عمومی ندارند (فقط service_role)


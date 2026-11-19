create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  source text,
  consent boolean not null default false,
  created_at timestamptz not null default now(),
  constraint leads_email_chk check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(email) <= 254),
  constraint leads_source_chk check (source is null or length(source) <= 60),
  constraint leads_consent_chk check (consent = true)
);
create unique index if not exists leads_email_uidx on public.leads (lower(email));
alter table public.leads enable row level security;
revoke all on public.leads from anon, authenticated, public;
grant insert on public.leads to anon;
drop policy if exists "anon can insert leads" on public.leads;
create policy "anon can insert leads" on public.leads for insert to anon with check (consent = true);

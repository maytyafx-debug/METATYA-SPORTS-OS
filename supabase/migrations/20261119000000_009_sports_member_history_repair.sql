-- METATYA Sports OS: tenant-scoped member history.
-- Reconciles the previously recorded 009 migration with the current multi-tenant schema.
-- Safe to re-run: columns, table, indexes and policies are guarded/idempotent.

begin;

alter table public.sports_members
  add column if not exists birth_date date,
  add column if not exists membership_number varchar(50),
  add column if not exists category varchar(100);

create table if not exists public.sports_member_history (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
  member_id uuid not null,
  changed_by uuid references auth.users(id) on delete set null,
  change_type varchar(50) not null
    check (change_type in ('create', 'update', 'deactivate')),
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now(),
  constraint sports_member_history_member_tenant_fk
    foreign key (member_id, tenant_id)
    references public.sports_members(id, tenant_id)
    on delete cascade
);

create index if not exists sports_member_history_tenant_member_created_idx
  on public.sports_member_history (tenant_id, member_id, created_at desc);

alter table public.sports_member_history enable row level security;

drop policy if exists sports_member_history_select_admin
  on public.sports_member_history;
drop policy if exists sports_member_history_insert_admin
  on public.sports_member_history;
drop policy if exists "Admins can view history"
  on public.sports_member_history;
drop policy if exists "Admins can insert history"
  on public.sports_member_history;

create policy sports_member_history_select_admin
  on public.sports_member_history
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.sports_tenant_memberships m
      where m.tenant_id = sports_member_history.tenant_id
        and m.user_id = (select auth.uid())
        and m.status = 'active'
        and m.role in ('owner', 'admin')
    )
  );

create policy sports_member_history_insert_admin
  on public.sports_member_history
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.sports_tenant_memberships m
      where m.tenant_id = sports_member_history.tenant_id
        and m.user_id = (select auth.uid())
        and m.status = 'active'
        and m.role in ('owner', 'admin')
    )
  );

grant select, insert on public.sports_member_history to authenticated;

commit;

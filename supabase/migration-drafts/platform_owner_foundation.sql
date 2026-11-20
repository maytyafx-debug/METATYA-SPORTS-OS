-- DRAFT ONLY — do not apply directly.
-- Generate the real migration filename with: supabase migration new platform_owner_foundation
-- Then copy this reviewed SQL into the generated file.
-- Depends on the reconciled tenant-security, member-history, and volleyball migrations.
-- This file is intentionally outside supabase/migrations until CLI-generated migration creation is available.

begin;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table if not exists private.platform_owners (
  singleton boolean primary key default true check (singleton is true),
  user_id uuid not null unique references auth.users(id) on delete restrict,
  status text not null default 'active' check (status in ('active','disabled')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete restrict
);

alter table private.platform_owners enable row level security;
alter table private.platform_owners force row level security;
revoke all on private.platform_owners from public, anon;
grant select on private.platform_owners to authenticated;
drop policy if exists platform_owners_read_self on private.platform_owners;
create policy platform_owners_read_self
on private.platform_owners for select to authenticated
using (user_id = (select auth.uid()) and status = 'active');

create or replace function private.is_platform_owner()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from private.platform_owners o
    where o.user_id = (select auth.uid())
      and o.status = 'active'
  );
$$;
revoke all on function private.is_platform_owner() from public, anon;
grant execute on function private.is_platform_owner() to authenticated;

create or replace function public.is_platform_owner()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select private.is_platform_owner();
$$;
revoke all on function public.is_platform_owner() from public, anon;
grant execute on function public.is_platform_owner() to authenticated;

create or replace function private.has_platform_or_active_tenant_role(
  p_tenant_id uuid,
  p_roles text[] default null
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select private.is_platform_owner()
    or private.has_active_tenant_role(p_tenant_id, p_roles);
$$;
revoke all on function private.has_platform_or_active_tenant_role(uuid,text[]) from public, anon;
grant execute on function private.has_platform_or_active_tenant_role(uuid,text[]) to authenticated;

create table if not exists private.platform_audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid not null references auth.users(id) on delete restrict,
  action text not null check (action ~ '^platform\\.[a-z0-9_.-]{1,100}$' or action ~ '^member\\.private\\.[a-z0-9_.-]{1,80}$'),
  target_type text not null check (char_length(target_type) between 1 and 80),
  target_id uuid,
  tenant_id uuid,
  reason text not null check (char_length(trim(reason)) between 5 and 500),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

alter table private.platform_audit_events enable row level security;
alter table private.platform_audit_events force row level security;
revoke all on private.platform_audit_events from public, anon, authenticated;
grant select on private.platform_audit_events to authenticated;
drop policy if exists platform_audit_events_read_owner on private.platform_audit_events;
create policy platform_audit_events_read_owner
on private.platform_audit_events for select to authenticated
using (private.is_platform_owner());

create or replace function private.reject_platform_audit_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'platform audit events are append-only' using errcode = '55000';
end;
$$;
revoke all on function private.reject_platform_audit_mutation() from public, anon, authenticated;
drop trigger if exists platform_audit_events_immutable on private.platform_audit_events;
create trigger platform_audit_events_immutable
before update or delete on private.platform_audit_events
for each row execute function private.reject_platform_audit_mutation();

create or replace function public.platform_audit_record(
  p_action text,
  p_target_type text,
  p_target_id uuid default null,
  p_tenant_id uuid default null,
  p_reason text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare v_id bigint;
begin
  if auth.uid() is null or not private.is_platform_owner() then
    raise exception 'platform owner required' using errcode = '42501';
  end if;
  if p_action is null or p_action !~ '^platform\\.[a-z0-9_.-]{1,100}$'
     and p_action !~ '^member\\.private\\.[a-z0-9_.-]{1,80}$' then
    raise exception 'invalid audit action' using errcode = '22023';
  end if;
  if p_target_type is null or char_length(p_target_type) not between 1 and 80
     or p_reason is null or char_length(trim(p_reason)) not between 5 and 500
     or p_metadata is null or jsonb_typeof(p_metadata) <> 'object'
     or octet_length(p_metadata::text) > 4096 then
    raise exception 'invalid audit metadata' using errcode = '22023';
  end if;

  insert into private.platform_audit_events
    (actor_id,action,target_type,target_id,tenant_id,reason,metadata)
  values
    (auth.uid(),p_action,p_target_type,p_target_id,p_tenant_id,trim(p_reason),p_metadata)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.platform_audit_record(text,text,uuid,uuid,text,jsonb) from public, anon;
grant execute on function public.platform_audit_record(text,text,uuid,uuid,text,jsonb) to authenticated;

-- The global owner can manage tenant-scoped operational data without synthetic
-- membership rows. Existing tenant policies remain in place for other users.
drop policy if exists platform_owner_manage_tenants on public.sports_tenants;
create policy platform_owner_manage_tenants
on public.sports_tenants for all to authenticated
using (private.is_platform_owner())
with check (private.is_platform_owner());

do $$
declare v_table text;
begin
  foreach v_table in array array[
    'sports_tenant_memberships',
    'sports_members',
    'sports_events',
    'sports_results',
    'sports_volleyball_teams',
    'sports_volleyball_team_members',
    'sports_volleyball_competitions',
    'sports_volleyball_competition_teams',
    'sports_volleyball_matches',
    'sports_volleyball_match_sets',
    'sports_volleyball_match_rosters',
    'sports_volleyball_match_officials'
  ] loop
    execute format('drop policy if exists platform_owner_manage on public.%I',v_table);
    execute format(
      'create policy platform_owner_manage on public.%I for all to authenticated using (private.is_platform_owner()) with check (private.is_platform_owner())',
      v_table
    );
  end loop;
end;
$$;

-- Audit/history data is globally readable by the Platform Owner, never writable.
drop policy if exists platform_owner_read_member_history on public.sports_member_history;
create policy platform_owner_read_member_history
on public.sports_member_history for select to authenticated
using (private.is_platform_owner());

drop policy if exists platform_owner_read_volleyball_audit on public.sports_volleyball_result_audit;
create policy platform_owner_read_volleyball_audit
on public.sports_volleyball_result_audit for select to authenticated
using (private.is_platform_owner());

-- Private athlete fields are not exposed by a broad owner SELECT policy.
-- Read/write is mediated by audited RPCs so sensitive access leaves evidence.
create or replace function public.platform_owner_read_member_private(
  p_member_id uuid,
  p_tenant_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.sports_member_private%rowtype;
begin
  if auth.uid() is null or not private.is_platform_owner() then
    raise exception 'platform owner required' using errcode = '42501';
  end if;
  if p_member_id is null or p_tenant_id is null
     or p_reason is null or char_length(trim(p_reason)) not between 5 and 500 then
    raise exception 'member, tenant and valid reason are required' using errcode = '22023';
  end if;

  insert into private.platform_audit_events
    (actor_id,action,target_type,target_id,tenant_id,reason,metadata)
  values
    (auth.uid(),'member.private.read','sports_member_private',p_member_id,p_tenant_id,
     trim(p_reason),jsonb_build_object('member_id',p_member_id));

  select * into v_row
  from public.sports_member_private
  where member_id=p_member_id and tenant_id=p_tenant_id;
  if not found then return null; end if;

  return jsonb_build_object(
    'member_id',v_row.member_id,
    'tenant_id',v_row.tenant_id,
    'phone',v_row.phone,
    'birth_date',v_row.birth_date
  );
end;
$$;
revoke all on function public.platform_owner_read_member_private(uuid,uuid,text) from public, anon;
grant execute on function public.platform_owner_read_member_private(uuid,uuid,text) to authenticated;

create or replace function public.platform_owner_upsert_member_private(
  p_member_id uuid,
  p_tenant_id uuid,
  p_phone text,
  p_birth_date date,
  p_reason text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not private.is_platform_owner() then
    raise exception 'platform owner required' using errcode = '42501';
  end if;
  if p_member_id is null or p_tenant_id is null
     or p_reason is null or char_length(trim(p_reason)) not between 5 and 500
     or p_phone is not null and char_length(p_phone)>80 then
    raise exception 'invalid private member update' using errcode = '22023';
  end if;

  insert into public.sports_member_private(member_id,tenant_id,phone,birth_date)
  values(p_member_id,p_tenant_id,p_phone,p_birth_date)
  on conflict(member_id,tenant_id) do update
    set phone=excluded.phone,birth_date=excluded.birth_date,updated_at=now();

  insert into private.platform_audit_events
    (actor_id,action,target_type,target_id,tenant_id,reason,metadata)
  values
    (auth.uid(),'member.private.update','sports_member_private',p_member_id,p_tenant_id,
     trim(p_reason),jsonb_build_object('phone_present',p_phone is not null,'birth_date_present',p_birth_date is not null));
  return true;
end;
$$;
revoke all on function public.platform_owner_upsert_member_private(uuid,uuid,text,date,text) from public, anon;
grant execute on function public.platform_owner_upsert_member_private(uuid,uuid,text,date,text) to authenticated;

-- No broad Storage policy is added here. The only live bucket observed is
-- "paid-packs", which has no object policies and is not tenant-scoped.
-- Add Platform Owner Storage access only with a server-mediated, audited
-- signing/download path; direct SELECT policies would permit unlogged reads.

commit;

-- IMPORTANT: Do not insert the founder UUID in this migration.
-- Bootstrap is a separate controlled step after live backup verification,
-- Auth UUID re-verification, migration-chain reconciliation and explicit approval.

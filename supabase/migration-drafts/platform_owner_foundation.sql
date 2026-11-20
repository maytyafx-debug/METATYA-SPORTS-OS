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

-- Keep a tenant-only predicate for private athlete fields. The general helper
-- below gains the Platform Owner exception, while private data remains tenant-
-- scoped unless read through the audited owner RPCs further below.
create or replace function private.has_active_tenant_role_only(
  p_tenant_id uuid,
  p_roles text[] default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.sports_tenant_memberships m
    join public.sports_tenants t on t.id=m.tenant_id
    where m.tenant_id=p_tenant_id
      and m.user_id=(select auth.uid())
      and m.status='active'
      and t.status='active'
      and (p_roles is null or m.role=any(p_roles))
  );
$$;
revoke all on function private.has_active_tenant_role_only(uuid,text[]) from public, anon;
grant execute on function private.has_active_tenant_role_only(uuid,text[]) to authenticated;

-- This is the central compatibility point used by existing RLS policies and
-- volleyball RPCs. Platform Owner is global; tenant roles remain unchanged.
create or replace function private.has_active_tenant_role(
  p_tenant_id uuid,
  p_roles text[] default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_platform_owner()
    or private.has_active_tenant_role_only(p_tenant_id,p_roles);
$$;
revoke all on function private.has_active_tenant_role(uuid,text[]) from public, anon;
grant execute on function private.has_active_tenant_role(uuid,text[]) to authenticated;

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
    or private.has_active_tenant_role_only(p_tenant_id,p_roles);
$$;
revoke all on function private.has_platform_or_active_tenant_role(uuid,text[]) from public, anon;
grant execute on function private.has_platform_or_active_tenant_role(uuid,text[]) to authenticated;

create table if not exists private.platform_audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid not null references auth.users(id) on delete restrict,
  action text not null check (action ~ '^platform[.][a-z0-9_.-]{1,100}$' or action ~ '^member[.]private[.][a-z0-9_.-]{1,80}$'),
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
  if p_action is null
     or (p_action !~ '^platform[.][a-z0-9_.-]{1,100}$'
         and p_action !~ '^member[.]private[.][a-z0-9_.-]{1,80}$') then
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

-- Global owner policies are additive. Existing tenant policies continue to
-- protect every other authenticated principal.
drop policy if exists platform_owner_manage_tenants on public.sports_tenants;
create policy platform_owner_manage_tenants
on public.sports_tenants for all to authenticated
using (private.is_platform_owner())
with check (private.is_platform_owner());
grant insert, update on public.sports_tenants to authenticated;

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

-- Do not let the global-owner exception expose private athlete fields through
-- direct PostgREST table access. Tenant owners/admins retain their scoped access.
drop policy if exists sports_member_private_select_admin on public.sports_member_private;
drop policy if exists sports_member_private_insert_admin on public.sports_member_private;
drop policy if exists sports_member_private_update_admin on public.sports_member_private;
drop policy if exists sports_member_private_delete_owner on public.sports_member_private;
create policy sports_member_private_select_admin
on public.sports_member_private for select to authenticated
using (private.has_active_tenant_role_only(tenant_id,array['owner','admin']::text[]));
create policy sports_member_private_insert_admin
on public.sports_member_private for insert to authenticated
with check (private.has_active_tenant_role_only(tenant_id,array['owner','admin']::text[]));
create policy sports_member_private_update_admin
on public.sports_member_private for update to authenticated
using (private.has_active_tenant_role_only(tenant_id,array['owner','admin']::text[]))
with check (private.has_active_tenant_role_only(tenant_id,array['owner','admin']::text[]));
create policy sports_member_private_delete_owner
on public.sports_member_private for delete to authenticated
using (private.has_active_tenant_role_only(tenant_id,array['owner']::text[]));

-- Audit/history data is globally readable by the Platform Owner, never writable.
drop policy if exists platform_owner_read_member_history on public.sports_member_history;
create policy platform_owner_read_member_history
on public.sports_member_history for select to authenticated
using (private.is_platform_owner());

drop policy if exists platform_owner_read_volleyball_audit on public.sports_volleyball_result_audit;
create policy platform_owner_read_volleyball_audit
on public.sports_volleyball_result_audit for select to authenticated
using (private.is_platform_owner());

-- Sensitive private-member reads and updates are mediated by audited RPCs.
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

-- Automatically append an audit event for Platform Owner mutations to
-- operational records. Only operation metadata is recorded, never row payloads.
create or replace function private.capture_platform_owner_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_row jsonb; v_target_id uuid; v_tenant_id uuid;
begin
  if auth.uid() is null or not private.is_platform_owner() then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_op='DELETE' then v_row:=to_jsonb(old); else v_row:=to_jsonb(new); end if;
  v_target_id:=nullif(v_row->>'id','')::uuid;
  v_tenant_id:=nullif(v_row->>'tenant_id','')::uuid;

  insert into private.platform_audit_events
    (actor_id,action,target_type,target_id,tenant_id,reason,metadata)
  values
    (auth.uid(),'platform.data.'||lower(tg_op),tg_table_name,v_target_id,v_tenant_id,
     'Automatic audit of Platform Owner data mutation',
     jsonb_build_object('operation',lower(tg_op)));

  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;
revoke all on function private.capture_platform_owner_mutation() from public, anon, authenticated;

do $$
declare v_table text;
begin
  foreach v_table in array array[
    'sports_tenants','sports_tenant_memberships','sports_members',
    'sports_events','sports_results','sports_volleyball_teams',
    'sports_volleyball_team_members','sports_volleyball_competitions',
    'sports_volleyball_competition_teams','sports_volleyball_matches',
    'sports_volleyball_match_rosters','sports_volleyball_match_officials'
  ] loop
    execute format('drop trigger if exists %I on public.%I',v_table||'_platform_owner_audit',v_table);
    execute format(
      'create trigger %I after insert or update or delete on public.%I for each row execute function private.capture_platform_owner_mutation()',
      v_table||'_platform_owner_audit',v_table
    );
  end loop;
end;
$$;

create or replace function public.platform_audit_list(
  p_limit integer default 50,
  p_before_id bigint default null
)
returns table (
  event_id bigint,
  actor_id uuid,
  action text,
  target_type text,
  target_id uuid,
  tenant_id uuid,
  reason text,
  metadata jsonb,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $
declare v_limit integer;
begin
  if auth.uid() is null or not private.is_platform_owner() then
    raise exception 'platform owner required' using errcode = '42501';
  end if;
  if p_before_id is not null and p_before_id < 1 then
    raise exception 'invalid audit cursor' using errcode = '22023';
  end if;
  v_limit := least(greatest(coalesce(p_limit,50),1),100);

  insert into private.platform_audit_events
    (actor_id,action,target_type,reason,metadata)
  values
    (auth.uid(),'platform.audit.read','platform_audit_events',
     'Platform Owner viewed audit event page',
     jsonb_build_object('limit',v_limit,'before_id',p_before_id));

  return query
  select e.id,e.actor_id,e.action,e.target_type,e.target_id,e.tenant_id,
         e.reason,e.metadata,e.created_at
  from private.platform_audit_events e
  where p_before_id is null or e.id < p_before_id
  order by e.id desc
  limit v_limit;
end;
$;
revoke all on function public.platform_audit_list(integer,bigint) from public, anon;
grant execute on function public.platform_audit_list(integer,bigint) to authenticated;

-- No broad Storage policy is added here. The only live bucket observed is
-- "paid-packs", which has no object policies and is not tenant-scoped.
-- Add Platform Owner Storage access only with a server-mediated, audited
-- signing/download path; direct SELECT policies would permit unlogged reads.

commit;

-- IMPORTANT: Do not insert the founder UUID in this migration.
-- Bootstrap is a separate controlled step after live backup verification,
-- Auth UUID re-verification, migration-chain reconciliation and explicit approval.

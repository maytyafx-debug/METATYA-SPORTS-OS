-- METATYA Sports OS: canonical tenant authorization and role alignment.
-- Follow-on hardening for the Sports OS schema after the currently applied migration ledger.
-- Additive hardening only: no application rows are deleted or rewritten.
-- Apply only after missing historical migration sources are restored and the local/live ledger is reconciled.
begin;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.has_active_tenant_role(
  p_tenant_id uuid,
  p_roles text[] default null
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from public.sports_tenant_memberships as m
    join public.sports_tenants as t on t.id = m.tenant_id
    where m.tenant_id = p_tenant_id
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and t.status = 'active'
      and (p_roles is null or m.role = any (p_roles))
  );
$$;

revoke all on function private.has_active_tenant_role(uuid, text[]) from public, anon;
grant execute on function private.has_active_tenant_role(uuid, text[]) to authenticated;

alter table public.sports_tenant_memberships
  drop constraint if exists sports_tenant_memberships_role_check;
alter table public.sports_tenant_memberships
  add constraint sports_tenant_memberships_role_check
  check (role in ('owner', 'admin', 'referee', 'coach', 'staff', 'member')) not valid;
alter table public.sports_tenant_memberships
  validate constraint sports_tenant_memberships_role_check;

-- Keep direct-contact and birth-date data out of the general member directory.
-- The source columns remain in place for rollback; authenticated users receive
-- access only to the non-sensitive directory columns.
alter table public.sports_members
  add column if not exists birth_date date;

create table if not exists public.sports_member_private (
  member_id uuid not null,
  tenant_id uuid not null,
  phone text,
  birth_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (member_id, tenant_id),
  foreign key (member_id, tenant_id)
    references public.sports_members(id, tenant_id) on delete cascade
);

insert into public.sports_member_private (member_id, tenant_id, phone, birth_date)
select id, tenant_id, phone, birth_date
from public.sports_members
where phone is not null or birth_date is not null
on conflict (member_id, tenant_id) do nothing;

create or replace function public.sports_prevent_tenant_change()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if new.tenant_id is distinct from old.tenant_id then
    raise exception 'tenant_id is immutable' using errcode = '42501';
  end if;
  if tg_table_name = 'sports_tenant_memberships' then
    if new.user_id is distinct from old.user_id then
      raise exception 'membership user_id is immutable' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists sports_members_tenant_immutable on public.sports_members;
create trigger sports_members_tenant_immutable
before update on public.sports_members
for each row execute function public.sports_prevent_tenant_change();

drop trigger if exists sports_events_tenant_immutable on public.sports_events;
create trigger sports_events_tenant_immutable
before update on public.sports_events
for each row execute function public.sports_prevent_tenant_change();

drop trigger if exists sports_results_tenant_immutable on public.sports_results;
create trigger sports_results_tenant_immutable
before update on public.sports_results
for each row execute function public.sports_prevent_tenant_change();

drop trigger if exists sports_memberships_identity_immutable on public.sports_tenant_memberships;
create trigger sports_memberships_identity_immutable
before update on public.sports_tenant_memberships
for each row execute function public.sports_prevent_tenant_change();

create or replace function private.prevent_last_active_owner_removal()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  remaining_owners integer;
  removing_owner boolean;
begin
  removing_owner := old.role = 'owner' and old.status = 'active';
  if tg_op = 'UPDATE' then
    removing_owner := removing_owner and (
      new.role is distinct from old.role
      or new.status is distinct from old.status
      or new.user_id is distinct from old.user_id
    );
  end if;

  if removing_owner then
    -- Serialize owner-removal checks for this tenant.
    perform pg_advisory_xact_lock(hashtextextended(old.tenant_id::text, 0));

    select count(*)::integer
      into remaining_owners
    from public.sports_tenant_memberships as m
    where m.tenant_id = old.tenant_id
      and m.role = 'owner'
      and m.status = 'active'
      and m.id <> old.id;

    if remaining_owners = 0 then
      raise exception 'a tenant must retain at least one active owner'
        using errcode = '23514';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.prevent_last_active_owner_removal() from public, anon, authenticated;
drop trigger if exists sports_tenant_keep_active_owner on public.sports_tenant_memberships;
create trigger sports_tenant_keep_active_owner
before update or delete on public.sports_tenant_memberships
for each row execute function private.prevent_last_active_owner_removal();

alter table public.sports_tenants enable row level security;
alter table public.sports_tenants force row level security;
alter table public.sports_tenant_memberships enable row level security;
alter table public.sports_tenant_memberships force row level security;
alter table public.sports_members enable row level security;
alter table public.sports_members force row level security;
alter table public.sports_events enable row level security;
alter table public.sports_events force row level security;
alter table public.sports_results enable row level security;
alter table public.sports_results force row level security;
alter table public.sports_member_private enable row level security;
alter table public.sports_member_private force row level security;

drop policy if exists sports_tenants_select_member on public.sports_tenants;
drop policy if exists sports_tenants_select_active_member on public.sports_tenants;
create policy sports_tenants_select_active_member
on public.sports_tenants for select to authenticated
using ((select private.has_active_tenant_role(id, null)));

drop policy if exists sports_memberships_select_self on public.sports_tenant_memberships;
drop policy if exists sports_tenant_memberships_select_self on public.sports_tenant_memberships;
drop policy if exists sports_tenant_memberships_select_self_or_admin on public.sports_tenant_memberships;
create policy sports_tenant_memberships_select_self_or_admin
on public.sports_tenant_memberships for select to authenticated
using (
  user_id = (select auth.uid())
  or (select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[]))
);

drop policy if exists sports_tenant_memberships_insert_admin on public.sports_tenant_memberships;
create policy sports_tenant_memberships_insert_admin
on public.sports_tenant_memberships for insert to authenticated
with check (
  (select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[]))
  and (role <> 'owner' or (select private.has_active_tenant_role(tenant_id, array['owner']::text[])))
);

drop policy if exists sports_tenant_memberships_update_admin on public.sports_tenant_memberships;
create policy sports_tenant_memberships_update_admin
on public.sports_tenant_memberships for update to authenticated
using (
  (select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[]))
  and (role <> 'owner' or (select private.has_active_tenant_role(tenant_id, array['owner']::text[])))
)
with check (
  (select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[]))
  and (role <> 'owner' or (select private.has_active_tenant_role(tenant_id, array['owner']::text[])))
);

drop policy if exists sports_tenant_memberships_delete_admin on public.sports_tenant_memberships;
create policy sports_tenant_memberships_delete_admin
on public.sports_tenant_memberships for delete to authenticated
using (
  (select private.has_active_tenant_role(tenant_id, array['owner']::text[]))
  or (
    role <> 'owner'
    and (select private.has_active_tenant_role(tenant_id, array['admin']::text[]))
  )
);

drop policy if exists sports_members_select_member on public.sports_members;
drop policy if exists sports_members_select_admin_referee on public.sports_members;
create policy sports_members_select_tenant
on public.sports_members for select to authenticated
using ((select private.has_active_tenant_role(
  tenant_id, array['owner', 'admin', 'referee', 'coach', 'staff']::text[]
)));

drop policy if exists sports_members_insert_staff on public.sports_members;
drop policy if exists sports_members_insert_admin on public.sports_members;
create policy sports_members_insert_authorized
on public.sports_members for insert to authenticated
with check ((select private.has_active_tenant_role(
  tenant_id, array['owner', 'admin', 'staff']::text[]
)));

drop policy if exists sports_members_update_admin on public.sports_members;
create policy sports_members_update_admin
on public.sports_members for update to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin', 'staff']::text[])))
with check ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin', 'staff']::text[])));

drop policy if exists sports_members_delete_admin on public.sports_members;
create policy sports_members_delete_admin
on public.sports_members for delete to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[])));

drop policy if exists sports_member_private_select_admin on public.sports_member_private;
create policy sports_member_private_select_admin
on public.sports_member_private for select to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[])));

drop policy if exists sports_member_private_insert_admin on public.sports_member_private;
create policy sports_member_private_insert_admin
on public.sports_member_private for insert to authenticated
with check ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[])));

drop policy if exists sports_member_private_update_admin on public.sports_member_private;
create policy sports_member_private_update_admin
on public.sports_member_private for update to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[])))
with check ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[])));

drop policy if exists sports_member_private_delete_owner on public.sports_member_private;
create policy sports_member_private_delete_owner
on public.sports_member_private for delete to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner']::text[])));

drop policy if exists sports_events_select_member on public.sports_events;
drop policy if exists sports_events_select_admin_referee on public.sports_events;
create policy sports_events_select_tenant
on public.sports_events for select to authenticated
using ((select private.has_active_tenant_role(
  tenant_id, array['owner', 'admin', 'referee', 'coach', 'staff', 'member']::text[]
)));

drop policy if exists sports_events_insert_staff on public.sports_events;
drop policy if exists sports_events_insert_admin on public.sports_events;
create policy sports_events_insert_authorized
on public.sports_events for insert to authenticated
with check ((select private.has_active_tenant_role(
  tenant_id, array['owner', 'admin', 'staff', 'coach']::text[]
)));

drop policy if exists sports_events_update_admin on public.sports_events;
create policy sports_events_update_admin
on public.sports_events for update to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[])))
with check ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[])));

drop policy if exists sports_events_delete_admin on public.sports_events;
create policy sports_events_delete_admin
on public.sports_events for delete to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner']::text[])));

drop policy if exists sports_results_select_member on public.sports_results;
drop policy if exists sports_results_select_admin_referee on public.sports_results;
create policy sports_results_select_tenant
on public.sports_results for select to authenticated
using ((select private.has_active_tenant_role(
  tenant_id, array['owner', 'admin', 'referee', 'coach', 'staff', 'member']::text[]
)));

drop policy if exists sports_results_insert_staff on public.sports_results;
drop policy if exists sports_results_insert_admin_referee on public.sports_results;
create policy sports_results_insert_authorized
on public.sports_results for insert to authenticated
with check ((select private.has_active_tenant_role(
  tenant_id, array['owner', 'admin', 'referee', 'coach', 'staff']::text[]
)));

drop policy if exists sports_results_update_admin on public.sports_results;
create policy sports_results_update_admin
on public.sports_results for update to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[])))
with check ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[])));

drop policy if exists sports_results_delete_admin on public.sports_results;
create policy sports_results_delete_admin
on public.sports_results for delete to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner']::text[])));

grant select on public.sports_tenants, public.sports_tenant_memberships,
  public.sports_members, public.sports_events, public.sports_results to authenticated;
grant insert, update, delete on public.sports_tenant_memberships to authenticated;
grant insert, update, delete on public.sports_events, public.sports_results to authenticated;

-- Restrict the general member directory to non-sensitive fields.
revoke all on public.sports_members from authenticated;
grant select (id, tenant_id, full_name, sport_type, status, created_at)
  on public.sports_members to authenticated;
grant insert (tenant_id, full_name, sport_type)
  on public.sports_members to authenticated;
grant update (full_name, sport_type, status)
  on public.sports_members to authenticated;
grant delete on public.sports_members to authenticated;

-- Sensitive member fields are available only through the separately protected table.
revoke all on public.sports_member_private from public, anon, authenticated;
grant select, insert, update, delete on public.sports_member_private to authenticated;

commit;

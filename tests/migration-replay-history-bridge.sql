\set ON_ERROR_STOP on
-- TEST-ONLY bridge for a verified unrecorded historical schema precondition.
-- The live table has tenant_id NOT NULL plus tenant and composite member/tenant FKs,
-- while the recorded 009 source creates a table without tenant_id.
-- This file is never applied to the connected/live Supabase project.

alter table public.sports_member_history
  add column if not exists tenant_id uuid;

update public.sports_member_history h
set tenant_id = m.tenant_id
from public.sports_members m
where h.member_id = m.id and h.tenant_id is null;

do $$
begin
  if exists (select 1 from public.sports_member_history where tenant_id is null) then
    raise exception 'history tenant_id could not be reconciled from its member';
  end if;
end
$$;

alter table public.sports_member_history
  alter column tenant_id set not null;

alter table public.sports_member_history
  drop constraint if exists sports_member_history_member_id_fkey;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.sports_member_history'::regclass
      and conname='sports_member_history_tenant_id_fkey'
  ) then
    alter table public.sports_member_history
      add constraint sports_member_history_tenant_id_fkey
      foreign key (tenant_id) references public.sports_tenants(id) on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.sports_member_history'::regclass
      and conname='sports_member_history_member_tenant_fk'
  ) then
    alter table public.sports_member_history
      add constraint sports_member_history_member_tenant_fk
      foreign key (member_id,tenant_id)
      references public.sports_members(id,tenant_id) on delete cascade;
  end if;
end
$$;

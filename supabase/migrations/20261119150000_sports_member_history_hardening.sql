-- METATYA Sports OS: harden member-history access and index its foreign keys.
-- Depends on the private.has_active_tenant_role helper from
-- 20261119120000_sports_tenant_security_alignment.sql.
-- The historical member-history table must exist from the reconciled prior migration chain.
begin;

alter table public.sports_member_history enable row level security;
alter table public.sports_member_history force row level security;

drop policy if exists sports_member_history_select_admin on public.sports_member_history;
create policy sports_member_history_select_admin
on public.sports_member_history for select to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[])));

drop policy if exists sports_member_history_insert_admin on public.sports_member_history;
create policy sports_member_history_insert_admin
on public.sports_member_history for insert to authenticated
with check ((select private.has_active_tenant_role(tenant_id, array['owner', 'admin']::text[])));

revoke all on public.sports_member_history from public, anon, authenticated;
grant select, insert on public.sports_member_history to authenticated;

create index if not exists sports_member_history_changed_by_idx
  on public.sports_member_history(changed_by);

create index if not exists sports_member_history_member_tenant_idx
  on public.sports_member_history(member_id, tenant_id);

commit;

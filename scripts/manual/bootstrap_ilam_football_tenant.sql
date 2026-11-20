-- Manual onboarding script for the Football Federation of Ilam.
-- Run only after the designated administrator has been created/invited in
-- Supabase Authentication > Users and has a confirmed auth.users UUID.
-- Replace the UUID below. This script is intentionally NOT auto-applied.
--
-- Project: megbqtoihsuouiaxpifl
-- Tenant slug: ilam-football
-- The script creates only the tenant and its administrator membership.
-- It does not modify any existing tenant or any existing sports records.

begin;

do $$
declare
  v_admin_user_id uuid := 'REPLACE_WITH_AUTH_USER_UUID'::uuid;
  v_tenant_id uuid;
begin
  if v_admin_user_id = '00000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'Replace the administrator UUID before running this script.';
  end if;

  if not exists (select 1 from auth.users where id = v_admin_user_id) then
    raise exception 'The administrator UUID does not exist in auth.users. Invite/create the user first.';
  end if;

  select id into v_tenant_id
  from public.sports_tenants
  where slug = 'ilam-football';

  if v_tenant_id is null then
    insert into public.sports_tenants (name, slug, status, created_by)
    values ('هیئت فوتبال ایلام', 'ilam-football', 'active', v_admin_user_id)
    returning id into v_tenant_id;
  else
    update public.sports_tenants
       set name = 'هیئت فوتبال ایلام',
           status = 'active',
           updated_at = now()
     where id = v_tenant_id;
  end if;

  insert into public.sports_tenant_memberships (tenant_id, user_id, role, status)
  values (v_tenant_id, v_admin_user_id, 'admin', 'active')
  on conflict (tenant_id, user_id)
  do update set role = 'admin', status = 'active';

  raise notice 'Football tenant ready: % (admin user: %)', v_tenant_id, v_admin_user_id;
end;
$$;

commit;

-- Manual onboarding script for the Football Federation of Ilam.
-- The designated administrator must first be created/invited in
-- Supabase Authentication with this exact, verified email address.
-- This script does not create Auth users or mailboxes.
--
-- Project: megbqtoihsuouiaxpifl
-- Tenant slug: ilam-football
-- The script creates only the tenant and its administrator membership.
-- It does not modify any existing tenant or any existing sports records.

begin;

do $$
declare
  v_admin_email text := 'admin@football.com';
  v_admin_user_id uuid;
  v_tenant_id uuid;
begin
  select id
    into v_admin_user_id
  from auth.users
  where lower(email) = lower(v_admin_email)
    and email_confirmed_at is not null;

  if v_admin_user_id is null then
    raise exception
      'A confirmed Supabase Auth user with email % must exist before running this script.',
      v_admin_email;
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

  raise notice 'Football tenant ready: % (admin email: %)', v_tenant_id, v_admin_email;
end;
$$;

commit;

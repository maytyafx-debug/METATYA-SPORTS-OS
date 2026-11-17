-- One-time sample setup. Replace the email with an existing Supabase Auth user.
-- This script does not overwrite an existing tenant name or membership role.
begin;
do $$
declare
  v_admin_email text := 'REPLACE_WITH_EXISTING_AUTH_EMAIL@example.com';
  v_user_id uuid;
  v_tenant_id uuid;
begin
  select id into v_user_id
  from auth.users
  where lower(email) = lower(trim(v_admin_email))
  limit 1;

  if v_user_id is null then
    raise exception 'No Supabase Auth user found for the configured email.';
  end if;

  insert into public.sports_tenants(name, slug, created_by)
  values ('باشگاه ورزشی نمونه', 'sample-sports-club', v_user_id)
  on conflict (slug) do nothing;

  select id into v_tenant_id
  from public.sports_tenants
  where slug = 'sample-sports-club';

  if v_tenant_id is null then
    raise exception 'Could not find or create the sample tenant.';
  end if;

  insert into public.sports_tenant_memberships(tenant_id, user_id, role, status)
  values (v_tenant_id, v_user_id, 'admin', 'active')
  on conflict (tenant_id, user_id) do nothing;
end $$;
commit;

-- Set the exact email of an existing Supabase Auth user before running.
begin;
do $$
declare
 v_admin_email text := 'REPLACE_WITH_EXISTING_AUTH_EMAIL@example.com';
 v_user_id uuid;
 v_tenant_id uuid;
begin
 select id into v_user_id from auth.users where lower(email)=lower(trim(v_admin_email)) limit 1;
 if v_user_id is null then raise exception 'No Supabase Auth user found for email: %',v_admin_email; end if;
 insert into public.sports_tenants(name,slug,created_by)
 values('باشگاه ورزشی نمونه','sample-sports-club',v_user_id)
 on conflict(slug) do update set name=excluded.name
 returning id into v_tenant_id;
 insert into public.sports_tenant_memberships(tenant_id,user_id,role,status)
 values(v_tenant_id,v_user_id,'admin','active')
 on conflict(tenant_id,user_id) do update set role='admin',status='active';
end $$;
commit;

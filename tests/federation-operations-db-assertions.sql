\set ON_ERROR_STOP on
do $$
declare
  v_table text;
  v_expected text[] := array[
    'sports_org_units','sports_member_memberships','sports_staff_profiles','sports_staff_credentials',
    'sports_member_guardian_consents','sports_training_programs','sports_training_sessions',
    'sports_training_attendance','sports_member_assessments','sports_member_development_plans',
    'sports_facilities','sports_facility_bookings','sports_fee_invoices','sports_fee_payments',
    'sports_member_insurance','sports_tenant_settings','sports_announcements','sports_platform_audit_events'
  ];
  v_count integer;
begin
  foreach v_table in array v_expected loop
    if to_regclass('public.'||v_table) is null then
      raise exception 'missing federation operations table: %',v_table;
    end if;
    select count(*) into v_count
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname=v_table and c.relrowsecurity and c.relforcerowsecurity;
    if v_count<>1 then raise exception 'RLS/FORCE RLS not enabled on %',v_table; end if;
    if has_table_privilege('anon','public.'||v_table,'SELECT') then
      raise exception 'anon unexpectedly has SELECT on %',v_table;
    end if;
  end loop;

  if not has_table_privilege('authenticated','public.sports_org_units','SELECT') then
    raise exception 'authenticated role is missing intended table SELECT grant';
  end if;
  if has_table_privilege('authenticated','public.sports_platform_audit_events','INSERT') then
    raise exception 'authenticated role must not directly insert audit events';
  end if;
  if not exists (
    select 1 from pg_trigger
    where tgname='sports_platform_audit_immutable'
      and not tgisinternal
  ) then raise exception 'append-only audit trigger is missing'; end if;

  if (select count(*) from pg_policies
      where schemaname='public' and tablename='sports_member_assessments') < 4 then
    raise exception 'assessment role policies are incomplete';
  end if;
end $$;

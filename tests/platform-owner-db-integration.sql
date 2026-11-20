\set ON_ERROR_STOP on

-- Synthetic Platform Owner has no tenant membership.
insert into auth.users(id) values
('10000000-0000-4000-8000-000000000099'),
('10000000-0000-4000-8000-000000000013'),
('10000000-0000-4000-8000-000000000014')
on conflict do nothing;

insert into public.sports_tenant_memberships(tenant_id,user_id,role,status) values
('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000013','admin','active'),
('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000014','member','active')
on conflict do nothing;

insert into private.platform_owners(singleton,user_id,status,created_by)
values(true,'10000000-0000-4000-8000-000000000099','active','10000000-0000-4000-8000-000000000099');

do $$
declare n integer;
begin
  select count(*) into n from public.sports_tenant_memberships
  where user_id='10000000-0000-4000-8000-000000000099';
  if n<>0 then raise exception 'Platform Owner must not require tenant membership'; end if;
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000099',false);
do $$
declare n integer; v_ok boolean;
begin
  if not public.is_platform_owner() then raise exception 'owner registry lookup failed'; end if;
  if not private.has_active_tenant_role('10000000-0000-4000-8000-000000000002',null) then
    raise exception 'global owner was not recognized for tenant two';
  end if;
  select count(*) into n from public.sports_tenants;
  if n<>4 then raise exception 'Platform Owner cannot inspect all tenants'; end if;
  select count(*) into n from public.sports_members;
  if n<>6 then raise exception 'Platform Owner cannot inspect all tenant members'; end if;
  select count(*) into n from public.sports_tenant_memberships;
  if n<10 then raise exception 'Platform Owner cannot inspect global memberships'; end if;
  select count(*) into n from public.sports_member_private
  where member_id='10000000-0000-4000-8000-000000000031';
  if n<>0 then raise exception 'Platform Owner private data must use audited RPC'; end if;

  v_ok:=public.platform_audit_record(
    'platform.test.access','platform_owner_test',null,null,
    'Synthetic owner authorization test',jsonb_build_object('test',true)
  ) is not null;
  if not v_ok then raise exception 'owner audit append failed'; end if;
end $$;

do $$
declare payload jsonb;
begin
  payload:=public.platform_owner_read_member_private(
    '10000000-0000-4000-8000-000000000031',
    '10000000-0000-4000-8000-000000000002',
    'Synthetic privacy boundary test'
  );
  if payload->>'phone' <> '+10000000002'
     or payload->>'birth_date' <> '2001-02-02' then
    raise exception 'audited private member read failed';
  end if;
end $$;

update public.sports_members set status='inactive'
where id='10000000-0000-4000-8000-000000000031'
  and tenant_id='10000000-0000-4000-8000-000000000002';

do $$
declare n integer;
begin
  select count(*) into n from private.platform_audit_events
  where actor_id='10000000-0000-4000-8000-000000000099'
    and action='platform.data.update'
    and target_type='sports_members'
    and target_id='10000000-0000-4000-8000-000000000031';
  if n<>1 then raise exception 'Platform Owner mutation audit missing'; end if;

  select count(*) into n from private.platform_audit_events
  where actor_id='10000000-0000-4000-8000-000000000099'
    and action='member.private.read';
  if n<>1 then raise exception 'private read audit missing'; end if;

  begin
    update private.platform_audit_events set reason='tampered';
    raise exception 'Platform Owner must not mutate audit evidence';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from private.platform_audit_events;
    raise exception 'Platform Owner must not delete audit evidence';
  exception when insufficient_privilege then null;
  end;
  begin
    update private.platform_owners set status='disabled';
    raise exception 'Platform Owner must not self-modify owner registry';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000013',false);
do $$
declare n integer; v_rows integer; v_status text;
begin
  if public.is_platform_owner() then raise exception 'tenant admin escalated to Platform Owner'; end if;
  select count(*) into n from public.sports_members
  where tenant_id='10000000-0000-4000-8000-000000000001';
  if n<>5 then raise exception 'tenant admin cannot read own tenant'; end if;
  select count(*) into n from public.sports_members
  where tenant_id='10000000-0000-4000-8000-000000000002';
  if n<>0 then raise exception 'tenant admin cross-tenant read leaked'; end if;
  update public.sports_members set status='active'
  where id='10000000-0000-4000-8000-000000000031';
  get diagnostics v_rows = row_count;
  if v_rows<>0 then raise exception 'tenant admin cross-tenant update succeeded'; end if;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000014',false);
do $$
declare n integer;
begin
  if public.is_platform_owner() then raise exception 'member escalated to Platform Owner'; end if;
  select count(*) into n from public.sports_tenant_memberships
  where tenant_id='10000000-0000-4000-8000-000000000002';
  if n<>0 then raise exception 'member cross-tenant membership read leaked'; end if;
  begin
    perform public.platform_owner_read_member_private(
      '10000000-0000-4000-8000-000000000031',
      '10000000-0000-4000-8000-000000000002',
      'Unauthorized member private read'
    );
    raise exception 'ordinary member called Platform Owner private-data RPC';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

\echo 'Platform Owner database authorization tests passed.'

\set ON_ERROR_STOP on
do $$
declare v_phone text; v_birth date; n integer; v_force boolean;
begin
 if has_column_privilege('authenticated','public.sports_members','phone','SELECT')
 or has_column_privilege('authenticated','public.sports_members','birth_date','SELECT')
 or has_column_privilege('anon','public.sports_members','phone','SELECT')
 or has_column_privilege('anon','public.sports_members','birth_date','SELECT')
 or has_column_privilege('authenticated','public.sports_members','phone','INSERT')
 or has_column_privilege('authenticated','public.sports_members','birth_date','UPDATE')
 then raise exception 'sensitive source-column grant remains'; end if;
 if has_table_privilege('authenticated','public.sports_member_history','INSERT')
 or has_table_privilege('authenticated','public.sports_member_history','UPDATE')
 or has_table_privilege('authenticated','public.sports_member_history','DELETE')
 or has_table_privilege('anon','public.sports_member_history','SELECT')
 or has_table_privilege('service_role','public.sports_member_history','INSERT')
 or has_table_privilege('service_role','public.sports_member_history','UPDATE')
 or has_table_privilege('service_role','public.sports_member_history','DELETE')
 or not has_table_privilege('service_role','public.sports_member_history','SELECT')
 then raise exception 'member history grants are not least privilege'; end if;
 if has_table_privilege('authenticated','public.sports_members','DELETE') then raise exception 'authenticated can hard-delete members'; end if;
 select relforcerowsecurity into v_force from pg_class where oid='public.sports_member_history'::regclass;
 if not coalesce(v_force,false) then raise exception 'member history FORCE RLS missing'; end if;
 select phone,birth_date into v_phone,v_birth from public.sports_member_private where member_id='10000000-0000-4000-8000-000000000030';
 if v_phone <> '+10000000001' or v_birth <> date '2000-01-01' then raise exception 'private data copy failed'; end if;
 if not has_function_privilege('authenticated','private.has_active_tenant_role(uuid,text[])','EXECUTE')
 or has_function_privilege('anon','private.has_active_tenant_role(uuid,text[])','EXECUTE')
 then raise exception 'tenant role helper grants incorrect'; end if;
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000010',false);
do $$ declare n integer;
begin
 select count(*) into n from public.sports_members where tenant_id='10000000-0000-4000-8000-000000000001';
 if n<>1 then raise exception 'tenant owner cannot read own directory'; end if;
 select count(*) into n from public.sports_members where tenant_id='10000000-0000-4000-8000-000000000002';
 if n<>0 then raise exception 'cross-tenant rows leaked'; end if;
 select count(*) into n from public.sports_member_private where member_id='10000000-0000-4000-8000-000000000030';
 if n<>1 then raise exception 'owner cannot read private data'; end if;
 begin perform phone from public.sports_members where id='10000000-0000-4000-8000-000000000030';
 raise exception 'phone should not be selectable'; exception when insufficient_privilege then null; end;
 begin insert into public.sports_member_history(tenant_id,member_id,change_type)
 values('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000030','update');
 raise exception 'direct audit insert should be denied'; exception when insufficient_privilege then null; end;
 begin delete from public.sports_members where id='10000000-0000-4000-8000-000000000030';
 raise exception 'hard member delete should be denied'; exception when insufficient_privilege then null; end;
 begin insert into public.sports_members(tenant_id,full_name,sport_type)
 values('10000000-0000-4000-8000-000000000002','Cross Tenant Insert','volleyball');
 raise exception 'cross-tenant insert should be denied'; exception when insufficient_privilege then null; end;
 begin update public.sports_members set tenant_id='10000000-0000-4000-8000-000000000002'
 where id='10000000-0000-4000-8000-000000000030';
 raise exception 'tenant reassignment should be denied'; exception when insufficient_privilege then null; end;
end $;
update public.sports_member_private set birth_date=date '2000-01-02'
 where member_id='10000000-0000-4000-8000-000000000030';
reset role;

do $ declare n integer; payload jsonb;
begin
 select count(*) into n from public.sports_member_history
 where member_id='10000000-0000-4000-8000-000000000030'
 and new_data->>'private_fields_updated'='true';
 if n<>1 then raise exception 'private-data history event missing'; end if;
 select new_data into payload from public.sports_member_history
 where member_id='10000000-0000-4000-8000-000000000030'
 and new_data->>'private_fields_updated'='true';
 if payload ? 'phone' or payload ? 'birth_date' then raise exception 'private data leaked into audit history'; end if;
end $;

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000011',false);
do $$ declare n integer;
begin
 select count(*) into n from public.sports_member_private where member_id='10000000-0000-4000-8000-000000000030';
 if n<>0 then raise exception 'coach can read private data'; end if;
 begin insert into public.sports_members(tenant_id,full_name,sport_type)
 values('10000000-0000-4000-8000-000000000001','Coach Forbidden','volleyball');
 raise exception 'coach should not create members'; exception when insufficient_privilege then null; end;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000010',false);
insert into public.sports_members(tenant_id,full_name,sport_type,membership_number,category)
values('10000000-0000-4000-8000-000000000001','Synthetic New Athlete','volleyball','SYN-003','adult');
reset role;

do $$ declare v_id uuid; n integer; payload jsonb;
begin
 select id into v_id from public.sports_members where full_name='Synthetic New Athlete';
 select count(*) into n from public.sports_member_history where member_id=v_id;
 if n<>1 then raise exception 'member creation history missing'; end if;
 select new_data into payload from public.sports_member_history where member_id=v_id;
 if payload ? 'phone' or payload ? 'birth_date' then raise exception 'sensitive data leaked into history'; end if;
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000010',false);
update public.sports_members set status='inactive' where full_name='Synthetic New Athlete';
do $$ declare n integer;
begin
 select count(*) into n from public.sports_member_history
 where member_id=(select id from public.sports_members where full_name='Synthetic New Athlete') and change_type='deactivate';
 if n<>1 then raise exception 'deactivation history missing'; end if;
 begin update public.sports_member_history set change_type='update';
 raise exception 'history update should be denied'; exception when insufficient_privilege then null; end;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000020',false);
do $$ begin
 begin update public.sports_tenant_memberships set status='left'
 where tenant_id='10000000-0000-4000-8000-000000000002' and user_id='10000000-0000-4000-8000-000000000020';
 raise exception 'last active owner removal should be denied'; exception when check_violation then null; end;
end $$;
reset role;
\echo 'Sports security and migration replay assertions passed.'

-- METATYA SPORT OS: close residual private-column grants and make member history append-only.
-- Depends on PR #5 migrations 012000/015000 and PR #6 migration 010.
-- Additive hardening only; no application rows are rewritten or deleted.
begin;
revoke all privileges (phone, birth_date) on table public.sports_members from public, anon, authenticated;
grant select (membership_number, category) on public.sports_members to authenticated;
grant insert (membership_number, category) on public.sports_members to authenticated;
grant update (membership_number, category) on public.sports_members to authenticated;
revoke delete on table public.sports_members from authenticated;
drop policy if exists sports_members_delete_admin on public.sports_members;

alter table public.sports_member_history enable row level security;
alter table public.sports_member_history force row level security;
drop policy if exists sports_member_history_insert_admin on public.sports_member_history;
revoke all privileges on table public.sports_member_history from public, anon, authenticated, service_role;
grant select on table public.sports_member_history to authenticated, service_role;

create or replace function private.capture_sports_member_history()
returns trigger language plpgsql security definer set search_path = pg_catalog
as $$
declare v_change_type varchar(50);
begin
  if tg_op = 'INSERT' then
    insert into public.sports_member_history
      (tenant_id,member_id,changed_by,change_type,old_data,new_data)
    values (new.tenant_id,new.id,auth.uid(),'create',null,
      to_jsonb(new)-'phone'-'birth_date');
    return new;
  end if;
  if to_jsonb(new) is distinct from to_jsonb(old) then
    v_change_type := case when old.status='active' and new.status in ('inactive','suspended')
      then 'deactivate' else 'update' end;
    insert into public.sports_member_history
      (tenant_id,member_id,changed_by,change_type,old_data,new_data)
    values (new.tenant_id,new.id,auth.uid(),v_change_type,
      to_jsonb(old)-'phone'-'birth_date',to_jsonb(new)-'phone'-'birth_date');
  end if;
  return new;
end;
$$;
revoke all on function private.capture_sports_member_history() from public, anon, authenticated;
drop trigger if exists sports_members_audit_history on public.sports_members;
create trigger sports_members_audit_history after insert or update on public.sports_members
for each row execute function private.capture_sports_member_history();

create or replace function private.capture_sports_member_private_history()
returns trigger language plpgsql security definer set search_path = pg_catalog
as $$
declare v_member_id uuid; v_tenant_id uuid; v_change_type varchar(50); v_event jsonb;
begin
  if tg_op='DELETE' then
    v_member_id:=old.member_id; v_tenant_id:=old.tenant_id;
    v_change_type:='update'; v_event:=jsonb_build_object('private_fields_removed',true);
  elsif tg_op='INSERT' then
    v_member_id:=new.member_id; v_tenant_id:=new.tenant_id;
    v_change_type:='create'; v_event:=jsonb_build_object('private_fields_created',true);
  else
    if new.phone is not distinct from old.phone and new.birth_date is not distinct from old.birth_date then return new; end if;
    v_member_id:=new.member_id; v_tenant_id:=new.tenant_id;
    v_change_type:='update'; v_event:=jsonb_build_object('private_fields_updated',true);
  end if;
  insert into public.sports_member_history
    (tenant_id,member_id,changed_by,change_type,old_data,new_data)
  values (v_tenant_id,v_member_id,auth.uid(),v_change_type,
    case when tg_op='INSERT' then null else jsonb_build_object('private_fields_present',true) end,
    v_event);
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function private.capture_sports_member_private_history() from public, anon, authenticated;
drop trigger if exists sports_member_private_audit_history on public.sports_member_private;
create trigger sports_member_private_audit_history after insert or update or delete
on public.sports_member_private for each row execute function private.capture_sports_member_private_history();

create or replace function private.reject_sports_member_history_mutation()
returns trigger language plpgsql set search_path = pg_catalog
as $$ begin
  raise exception 'sports member history is append-only' using errcode='55000';
end; $$;
revoke all on function private.reject_sports_member_history_mutation() from public, anon, authenticated;
drop trigger if exists sports_member_history_immutable on public.sports_member_history;
create trigger sports_member_history_immutable before update or delete
on public.sports_member_history for each row execute function private.reject_sports_member_history_mutation();
commit;

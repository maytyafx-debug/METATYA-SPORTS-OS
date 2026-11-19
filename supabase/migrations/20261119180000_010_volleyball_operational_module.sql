-- METATYA Sports OS / Volleyball module
-- Additive, tenant-scoped tables. Apply only after migration history reconciliation.
begin;

create table if not exists public.sports_volleyball_teams (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
  name varchar(140) not null check (char_length(trim(name)) between 2 and 140),
  gender varchar(20) not null default 'mixed' check (gender in ('women','men','mixed')),
  age_group varchar(50),
  category varchar(60),
  season varchar(30),
  home_venue varchar(180),
  status varchar(20) not null default 'active' check (status in ('active','inactive','archived')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, tenant_id)
);

create table if not exists public.sports_volleyball_team_members (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  team_id uuid not null,
  member_id uuid not null,
  jersey_number smallint check (jersey_number between 1 and 99),
  position varchar(20) check (position in ('setter','outside_hitter','opposite','middle_blocker','libero','defensive_specialist','unassigned')),
  is_captain boolean not null default false,
  status varchar(20) not null default 'active' check (status in ('active','inactive')),
  joined_at timestamptz not null default now(),
  unique (id, tenant_id),
  unique (team_id, member_id),
  foreign key (team_id, tenant_id) references public.sports_volleyball_teams(id, tenant_id) on delete cascade,
  foreign key (member_id, tenant_id) references public.sports_members(id, tenant_id) on delete restrict
);
create unique index if not exists sports_volleyball_team_jersey_unique
  on public.sports_volleyball_team_members(team_id, jersey_number)
  where jersey_number is not null and status = 'active';

create table if not exists public.sports_volleyball_competitions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
  name varchar(160) not null check (char_length(trim(name)) between 2 and 160),
  format varchar(30) not null default 'league' check (format in ('league','cup','round_robin','friendly','tournament')),
  season varchar(30),
  start_date date,
  end_date date,
  status varchar(20) not null default 'draft' check (status in ('draft','registration','in_progress','completed','cancelled')),
  points_win_clear smallint not null default 3 check (points_win_clear between 0 and 10),
  points_win_narrow smallint not null default 2 check (points_win_narrow between 0 and 10),
  points_loss_narrow smallint not null default 1 check (points_loss_narrow between 0 and 10),
  points_loss_clear smallint not null default 0 check (points_loss_clear between 0 and 10),
  description varchar(2000),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, tenant_id),
  check (end_date is null or start_date is null or end_date >= start_date)
);

create table if not exists public.sports_volleyball_competition_teams (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  competition_id uuid not null,
  team_id uuid not null,
  pool_code varchar(20),
  seed smallint check (seed is null or seed > 0),
  status varchar(20) not null default 'registered' check (status in ('registered','withdrawn')),
  registered_at timestamptz not null default now(),
  unique (competition_id, team_id),
  foreign key (competition_id, tenant_id) references public.sports_volleyball_competitions(id, tenant_id) on delete cascade,
  foreign key (team_id, tenant_id) references public.sports_volleyball_teams(id, tenant_id) on delete restrict
);

create table if not exists public.sports_volleyball_matches (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
  event_id uuid,
  competition_id uuid,
  stage_name varchar(80),
  round_number smallint check (round_number is null or round_number > 0),
  pool_code varchar(20),
  match_number varchar(40),
  home_team_id uuid not null,
  away_team_id uuid not null,
  scheduled_at timestamptz not null,
  venue varchar(180),
  best_of smallint not null default 5 check (best_of in (3,5)),
  status varchar(20) not null default 'scheduled' check (status in ('scheduled','live','completed','cancelled')),
  result_status varchar(20) not null default 'pending' check (result_status in ('pending','submitted','approved','rejected')),
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  notes varchar(2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (home_team_id <> away_team_id),
  unique (id, tenant_id),
  foreign key (home_team_id, tenant_id) references public.sports_volleyball_teams(id, tenant_id) on delete restrict,
  foreign key (away_team_id, tenant_id) references public.sports_volleyball_teams(id, tenant_id) on delete restrict,
  foreign key (event_id, tenant_id) references public.sports_events(id, tenant_id) on delete restrict,
  foreign key (competition_id, tenant_id) references public.sports_volleyball_competitions(id, tenant_id) on delete restrict
);

create table if not exists public.sports_volleyball_match_officials (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  match_id uuid not null,
  user_id uuid not null references auth.users(id) on delete restrict,
  official_role varchar(30) not null check (official_role in ('first_referee','second_referee','scorer','line_judge')),
  status varchar(20) not null default 'assigned' check (status in ('assigned','accepted','declined','replaced')),
  assigned_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (match_id,user_id,official_role),
  foreign key (match_id,tenant_id) references public.sports_volleyball_matches(id,tenant_id) on delete cascade
);

create table if not exists public.sports_volleyball_match_sets (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  match_id uuid not null,
  set_number smallint not null check (set_number between 1 and 5),
  home_points smallint not null check (home_points between 0 and 99),
  away_points smallint not null check (away_points between 0 and 99),
  recorded_by uuid references auth.users(id) on delete set null,
  recorded_at timestamptz not null default now(),
  unique (match_id, set_number),
  foreign key (match_id, tenant_id) references public.sports_volleyball_matches(id, tenant_id) on delete cascade
);

create table if not exists public.sports_volleyball_match_rosters (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  match_id uuid not null,
  team_id uuid not null,
  member_id uuid not null,
  jersey_number smallint check (jersey_number between 1 and 99),
  position varchar(20) check (position in ('setter','outside_hitter','opposite','middle_blocker','libero','defensive_specialist','unassigned')),
  is_starter boolean not null default false,
  created_at timestamptz not null default now(),
  unique (match_id, team_id, member_id),
  foreign key (match_id, tenant_id) references public.sports_volleyball_matches(id, tenant_id) on delete cascade,
  foreign key (team_id, tenant_id) references public.sports_volleyball_teams(id, tenant_id) on delete restrict,
  foreign key (member_id, tenant_id) references public.sports_members(id, tenant_id) on delete restrict
);

create table if not exists public.sports_volleyball_result_audit (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  match_id uuid not null,
  actor_id uuid references auth.users(id) on delete set null,
  action varchar(30) not null check (action in ('score_submitted','score_approved','score_rejected','score_corrected')),
  prior_result jsonb,
  new_result jsonb,
  reason varchar(1000),
  created_at timestamptz not null default now(),
  foreign key (match_id, tenant_id) references public.sports_volleyball_matches(id, tenant_id) on delete restrict
);

create index if not exists sports_volleyball_teams_tenant_status_idx on public.sports_volleyball_teams(tenant_id,status);
create index if not exists sports_volleyball_team_members_tenant_member_idx on public.sports_volleyball_team_members(tenant_id,member_id);
create index if not exists sports_volleyball_competitions_tenant_status_idx on public.sports_volleyball_competitions(tenant_id,status,start_date);
create index if not exists sports_volleyball_competition_teams_tenant_comp_idx on public.sports_volleyball_competition_teams(tenant_id,competition_id,status);
create index if not exists sports_volleyball_matches_tenant_competition_idx on public.sports_volleyball_matches(tenant_id,competition_id,scheduled_at);
create index if not exists sports_volleyball_match_officials_tenant_match_idx on public.sports_volleyball_match_officials(tenant_id,match_id,status);
create index if not exists sports_volleyball_matches_tenant_schedule_idx on public.sports_volleyball_matches(tenant_id,scheduled_at);
create index if not exists sports_volleyball_matches_tenant_status_idx on public.sports_volleyball_matches(tenant_id,status,result_status);
create index if not exists sports_volleyball_sets_tenant_match_idx on public.sports_volleyball_match_sets(tenant_id,match_id,set_number);
create index if not exists sports_volleyball_rosters_tenant_match_idx on public.sports_volleyball_match_rosters(tenant_id,match_id,team_id);
create index if not exists sports_volleyball_audit_tenant_match_idx on public.sports_volleyball_result_audit(tenant_id,match_id,created_at desc);

do $$
declare t text;
begin
  foreach t in array array[
    'sports_volleyball_teams','sports_volleyball_team_members','sports_volleyball_competitions',
    'sports_volleyball_competition_teams','sports_volleyball_matches','sports_volleyball_match_officials',
    'sports_volleyball_match_sets','sports_volleyball_match_rosters','sports_volleyball_result_audit'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
  end loop;
end $$;

-- All volleyball records are scoped to an active tenant membership.
create policy volleyball_teams_select on public.sports_volleyball_teams for select to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee','coach','staff','member']::text[])));
create policy volleyball_teams_insert on public.sports_volleyball_teams for insert to authenticated
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])));
create policy volleyball_teams_update on public.sports_volleyball_teams for update to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])))
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])));
create policy volleyball_teams_delete on public.sports_volleyball_teams for delete to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin']::text[])));


create policy volleyball_competitions_select on public.sports_volleyball_competitions for select to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee','coach','staff','member']::text[])));
create policy volleyball_competitions_insert on public.sports_volleyball_competitions for insert to authenticated
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff']::text[])));
create policy volleyball_competitions_update on public.sports_volleyball_competitions for update to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff']::text[])))
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff']::text[])));
create policy volleyball_competitions_delete on public.sports_volleyball_competitions for delete to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin']::text[])));

create policy volleyball_competition_teams_select on public.sports_volleyball_competition_teams for select to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee','coach','staff','member']::text[])));
create policy volleyball_competition_teams_insert on public.sports_volleyball_competition_teams for insert to authenticated
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])));
create policy volleyball_competition_teams_update on public.sports_volleyball_competition_teams for update to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])))
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])));
create policy volleyball_competition_teams_delete on public.sports_volleyball_competition_teams for delete to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff']::text[])));

create policy volleyball_team_members_select on public.sports_volleyball_team_members for select to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee','coach','staff']::text[])));
create policy volleyball_team_members_insert on public.sports_volleyball_team_members for insert to authenticated
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])));
create policy volleyball_team_members_update on public.sports_volleyball_team_members for update to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])))
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])));
create policy volleyball_team_members_delete on public.sports_volleyball_team_members for delete to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff']::text[])));

create policy volleyball_matches_select on public.sports_volleyball_matches for select to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee','coach','staff','member']::text[])));
create policy volleyball_matches_insert on public.sports_volleyball_matches for insert to authenticated
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])));
create policy volleyball_matches_update on public.sports_volleyball_matches for update to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee']::text[])))
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee']::text[])));
create policy volleyball_matches_delete on public.sports_volleyball_matches for delete to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin']::text[])));

create policy volleyball_officials_select on public.sports_volleyball_match_officials for select to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee','staff']::text[])));
create policy volleyball_officials_insert on public.sports_volleyball_match_officials for insert to authenticated
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff']::text[])));
create policy volleyball_officials_update on public.sports_volleyball_match_officials for update to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff']::text[])))
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff']::text[])));
create policy volleyball_officials_delete on public.sports_volleyball_match_officials for delete to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin']::text[])));

create policy volleyball_sets_select on public.sports_volleyball_match_sets for select to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee','coach','staff','member']::text[])));
create policy volleyball_sets_insert on public.sports_volleyball_match_sets for insert to authenticated
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee']::text[])));
create policy volleyball_sets_update on public.sports_volleyball_match_sets for update to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee']::text[])))
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee']::text[])));
create policy volleyball_sets_delete on public.sports_volleyball_match_sets for delete to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin']::text[])));

create policy volleyball_rosters_select on public.sports_volleyball_match_rosters for select to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee','coach','staff']::text[])));
create policy volleyball_rosters_insert on public.sports_volleyball_match_rosters for insert to authenticated
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])));
create policy volleyball_rosters_update on public.sports_volleyball_match_rosters for update to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])))
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff','coach']::text[])));
create policy volleyball_rosters_delete on public.sports_volleyball_match_rosters for delete to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','staff']::text[])));

create policy volleyball_result_audit_select on public.sports_volleyball_result_audit for select to authenticated
using ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee']::text[])));
create policy volleyball_result_audit_insert on public.sports_volleyball_result_audit for insert to authenticated
with check ((select private.has_active_tenant_role(tenant_id, array['owner','admin','referee']::text[])));

grant select, insert, update, delete on public.sports_volleyball_teams,
  public.sports_volleyball_competitions, public.sports_volleyball_competition_teams,
  public.sports_volleyball_team_members, public.sports_volleyball_matches,
  public.sports_volleyball_match_sets, public.sports_volleyball_match_rosters,
  public.sports_volleyball_match_officials to authenticated;
grant select, insert on public.sports_volleyball_result_audit to authenticated;
-- Explicitly deny PUBLIC/anonymous access. The audit table is read-only to
-- authenticated clients; inserts are performed by the SECURITY DEFINER RPCs.
revoke all privileges on table
  public.sports_volleyball_teams,
  public.sports_volleyball_team_members,
  public.sports_volleyball_competitions,
  public.sports_volleyball_competition_teams,
  public.sports_volleyball_matches,
  public.sports_volleyball_match_sets,
  public.sports_volleyball_match_rosters,
  public.sports_volleyball_match_officials,
  public.sports_volleyball_result_audit
from public, anon;

revoke insert, update, delete on public.sports_volleyball_result_audit from authenticated;
grant select on public.sports_volleyball_result_audit to authenticated;

create or replace function public.sports_volleyball_reject_audit_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog
as $
begin
  raise exception 'volleyball result audit is append-only' using errcode = '42501';
end;
$;

drop trigger if exists sports_volleyball_result_audit_immutable
  on public.sports_volleyball_result_audit;
create trigger sports_volleyball_result_audit_immutable
before update or delete on public.sports_volleyball_result_audit
for each row execute function public.sports_volleyball_reject_audit_mutation();

-- Tenant identity cannot be changed after creation.
create or replace function public.sports_volleyball_prevent_tenant_change()
returns trigger language plpgsql set search_path = pg_catalog as $$
begin
  if new.tenant_id is distinct from old.tenant_id then
    raise exception 'tenant_id is immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;
do $$
declare t text;
begin
  foreach t in array array[
    'sports_volleyball_teams','sports_volleyball_team_members','sports_volleyball_competitions',
    'sports_volleyball_competition_teams','sports_volleyball_matches','sports_volleyball_match_officials',
    'sports_volleyball_match_sets','sports_volleyball_match_rosters','sports_volleyball_result_audit'
  ] loop
    execute format('drop trigger if exists %I on public.%I', t || '_tenant_immutable', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.sports_volleyball_prevent_tenant_change()', t || '_tenant_immutable', t);
  end loop;
end $$;


-- Validate that match officials are active, scoped tenant members.
create or replace function public.sports_volleyball_validate_official()
returns trigger language plpgsql security definer set search_path = pg_catalog as $$
begin
  if not exists (
    select 1 from public.sports_tenant_memberships m
    where m.tenant_id=new.tenant_id and m.user_id=new.user_id and m.status='active'
      and (m.role='referee' or (new.official_role='scorer' and m.role='staff'))
  ) then
    raise exception 'official must be an active referee or authorized scorer in this tenant' using errcode='23514';
  end if;
  return new;
end;
$$;
revoke all on function public.sports_volleyball_validate_official() from public, anon, authenticated;
drop trigger if exists sports_volleyball_official_membership_check on public.sports_volleyball_match_officials;
create trigger sports_volleyball_official_membership_check
before insert or update on public.sports_volleyball_match_officials
for each row execute function public.sports_volleyball_validate_official();

-- A match lineup can only contain registered players from one of that match's teams.
create or replace function public.sports_volleyball_validate_match_roster()
returns trigger language plpgsql security definer set search_path = pg_catalog as $$
declare v_home uuid; v_away uuid;
begin
  select home_team_id,away_team_id into v_home,v_away
  from public.sports_volleyball_matches where id=new.match_id and tenant_id=new.tenant_id;
  if v_home is null or new.team_id not in (v_home,v_away) then
    raise exception 'match roster team must be one of the match teams' using errcode='23514';
  end if;
  if not exists (
    select 1 from public.sports_volleyball_team_members tm
    where tm.tenant_id=new.tenant_id and tm.team_id=new.team_id
      and tm.member_id=new.member_id and tm.status='active'
  ) then
    raise exception 'match roster athlete must be an active member of the selected team' using errcode='23514';
  end if;
  return new;
end;
$$;
revoke all on function public.sports_volleyball_validate_match_roster() from public, anon, authenticated;
drop trigger if exists sports_volleyball_match_roster_check on public.sports_volleyball_match_rosters;
create trigger sports_volleyball_match_roster_check
before insert or update on public.sports_volleyball_match_rosters
for each row execute function public.sports_volleyball_validate_match_roster();


create or replace function public.sports_volleyball_validate_competition_match()
returns trigger language plpgsql security definer set search_path = pg_catalog as $
begin
  if new.competition_id is not null then
    if not exists (
      select 1 from public.sports_volleyball_competition_teams ct
      where ct.tenant_id=new.tenant_id and ct.competition_id=new.competition_id
        and ct.team_id=new.home_team_id and ct.status='registered'
    ) or not exists (
      select 1 from public.sports_volleyball_competition_teams ct
      where ct.tenant_id=new.tenant_id and ct.competition_id=new.competition_id
        and ct.team_id=new.away_team_id and ct.status='registered'
    ) then
      raise exception 'both match teams must be registered in the selected competition' using errcode='23514';
    end if;
  end if;
  return new;
end;
$;
revoke all on function public.sports_volleyball_validate_competition_match() from public, anon, authenticated;
drop trigger if exists sports_volleyball_competition_match_check on public.sports_volleyball_matches;
create trigger sports_volleyball_competition_match_check
before insert or update on public.sports_volleyball_matches
for each row execute function public.sports_volleyball_validate_competition_match();

-- Atomic score submission: validation, audit, score replacement and match state
-- commit together or roll back together.
create or replace function public.sports_volleyball_submit_score(
  p_tenant_id uuid, p_match_id uuid, p_sets jsonb
) returns jsonb
language plpgsql security definer set search_path = pg_catalog
as $$
declare
  v_match public.sports_volleyball_matches%rowtype;
  v_item jsonb;
  v_index integer := 0;
  v_home integer;
  v_away integer;
  v_home_wins integer := 0;
  v_away_wins integer := 0;
  v_sets_to_win integer;
  v_target integer;
  v_prior jsonb;
  v_normalized jsonb := '[]'::jsonb;
  v_action text;
begin
  if auth.uid() is null or not private.has_active_tenant_role(
    p_tenant_id, array['owner','admin','referee']::text[]
  ) then raise exception 'not authorized to submit volleyball scores' using errcode='42501'; end if;

  select * into v_match from public.sports_volleyball_matches
  where id=p_match_id and tenant_id=p_tenant_id for update;
  if not found then raise exception 'match not found' using errcode='P0002'; end if;
  if v_match.result_status='approved' then raise exception 'approved result is locked' using errcode='55000'; end if;
  if p_sets is null or jsonb_typeof(p_sets)<>'array' then raise exception 'sets must be a JSON array' using errcode='22023'; end if;
  if jsonb_array_length(p_sets)<1 or jsonb_array_length(p_sets)>v_match.best_of then
    raise exception 'invalid number of sets' using errcode='22023';
  end if;

  v_sets_to_win := (v_match.best_of / 2) + 1;
  for v_item in select value from jsonb_array_elements(p_sets) loop
    v_index := v_index + 1;
    if coalesce(v_item->>'home','') !~ '^[0-9]{1,2}$'
       or coalesce(v_item->>'away','') !~ '^[0-9]{1,2}$' then
      raise exception 'set scores must be integers from 0 to 99' using errcode='22023';
    end if;
    v_home := (v_item->>'home')::integer;
    v_away := (v_item->>'away')::integer;
    if v_home=v_away then raise exception 'a set cannot be tied' using errcode='22023'; end if;
    v_target := case when v_index=v_match.best_of then 15 else 25 end;
    if greatest(v_home,v_away)<v_target or abs(v_home-v_away)<2 then
      raise exception 'set score does not satisfy volleyball rules' using errcode='22023';
    end if;
    if v_home>v_away then v_home_wins:=v_home_wins+1; else v_away_wins:=v_away_wins+1; end if;
    if (v_home_wins=v_sets_to_win or v_away_wins=v_sets_to_win)
       and v_index<jsonb_array_length(p_sets) then
      raise exception 'no sets may follow a completed match' using errcode='22023';
    end if;
    v_normalized:=v_normalized||jsonb_build_array(jsonb_build_object(
      'set_number',v_index,'home_points',v_home,'away_points',v_away
    ));
  end loop;
  if v_home_wins<>v_sets_to_win and v_away_wins<>v_sets_to_win then
    raise exception 'match is not complete' using errcode='22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'set_number',s.set_number,'home_points',s.home_points,'away_points',s.away_points
  ) order by s.set_number),'[]'::jsonb)
  into v_prior from public.sports_volleyball_match_sets s
  where s.tenant_id=p_tenant_id and s.match_id=p_match_id;

  v_action:=case when v_match.result_status='pending' then 'score_submitted' else 'score_corrected' end;
  insert into public.sports_volleyball_result_audit(tenant_id,match_id,actor_id,action,prior_result,new_result)
  values(p_tenant_id,p_match_id,auth.uid(),v_action,
    jsonb_build_object('sets',v_prior,'result_status',v_match.result_status),
    jsonb_build_object('sets',v_normalized,'home_sets_won',v_home_wins,'away_sets_won',v_away_wins));

  delete from public.sports_volleyball_match_sets where tenant_id=p_tenant_id and match_id=p_match_id;
  insert into public.sports_volleyball_match_sets(tenant_id,match_id,set_number,home_points,away_points,recorded_by)
  select p_tenant_id,p_match_id,(x->>'set_number')::smallint,
    (x->>'home_points')::smallint,(x->>'away_points')::smallint,auth.uid()
  from jsonb_array_elements(v_normalized) x;

  update public.sports_volleyball_matches
  set status='completed',result_status='submitted',approved_by=null,approved_at=null,updated_at=now()
  where id=p_match_id and tenant_id=p_tenant_id;

  return jsonb_build_object('ok',true,'home_sets_won',v_home_wins,'away_sets_won',v_away_wins);
end;
$$;

create or replace function public.sports_volleyball_decide_result(
  p_tenant_id uuid, p_match_id uuid, p_decision text, p_reason text default null
) returns jsonb
language plpgsql security definer set search_path = pg_catalog
as $$
declare v_match public.sports_volleyball_matches%rowtype;
begin
  if auth.uid() is null or not private.has_active_tenant_role(
    p_tenant_id,array['owner','admin']::text[]
  ) then raise exception 'not authorized to approve volleyball results' using errcode='42501'; end if;
  if p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'invalid result decision' using errcode='22023';
  end if;
  select * into v_match from public.sports_volleyball_matches
  where id=p_match_id and tenant_id=p_tenant_id for update;
  if not found then raise exception 'match not found' using errcode='P0002'; end if;
  if v_match.result_status<>'submitted' then
    raise exception 'only submitted results can be reviewed' using errcode='55000';
  end if;
  insert into public.sports_volleyball_result_audit(tenant_id,match_id,actor_id,action,new_result,reason)
  values(p_tenant_id,p_match_id,auth.uid(),
    case when p_decision='approved' then 'score_approved' else 'score_rejected' end,
    jsonb_build_object('decision',p_decision),left(coalesce(p_reason,''),1000));
  update public.sports_volleyball_matches
  set result_status=p_decision,
      approved_by=case when p_decision='approved' then auth.uid() else null end,
      approved_at=case when p_decision='approved' then now() else null end,
      updated_at=now()
  where id=p_match_id and tenant_id=p_tenant_id;
  return jsonb_build_object('ok',true,'result_status',p_decision);
end;
$$;

revoke all on function public.sports_volleyball_submit_score(uuid,uuid,jsonb) from public, anon;
revoke all on function public.sports_volleyball_decide_result(uuid,uuid,text,text) from public, anon;
grant execute on function public.sports_volleyball_submit_score(uuid,uuid,jsonb) to authenticated;
grant execute on function public.sports_volleyball_decide_result(uuid,uuid,text,text) to authenticated;

commit;

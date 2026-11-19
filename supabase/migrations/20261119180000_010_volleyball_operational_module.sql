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

create table if not exists public.sports_volleyball_matches (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
  event_id uuid,
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
  foreign key (event_id, tenant_id) references public.sports_events(id, tenant_id) on delete set null
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
create index if not exists sports_volleyball_matches_tenant_schedule_idx on public.sports_volleyball_matches(tenant_id,scheduled_at);
create index if not exists sports_volleyball_matches_tenant_status_idx on public.sports_volleyball_matches(tenant_id,status,result_status);
create index if not exists sports_volleyball_sets_tenant_match_idx on public.sports_volleyball_match_sets(tenant_id,match_id,set_number);
create index if not exists sports_volleyball_rosters_tenant_match_idx on public.sports_volleyball_match_rosters(tenant_id,match_id,team_id);
create index if not exists sports_volleyball_audit_tenant_match_idx on public.sports_volleyball_result_audit(tenant_id,match_id,created_at desc);

do $$
declare t text;
begin
  foreach t in array array[
    'sports_volleyball_teams','sports_volleyball_team_members','sports_volleyball_matches',
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
  public.sports_volleyball_team_members, public.sports_volleyball_matches,
  public.sports_volleyball_match_sets, public.sports_volleyball_match_rosters to authenticated;
grant select, insert on public.sports_volleyball_result_audit to authenticated;

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
    'sports_volleyball_teams','sports_volleyball_team_members','sports_volleyball_matches',
    'sports_volleyball_match_sets','sports_volleyball_match_rosters','sports_volleyball_result_audit'
  ] loop
    execute format('drop trigger if exists %I on public.%I', t || '_tenant_immutable', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.sports_volleyball_prevent_tenant_change()', t || '_tenant_immutable', t);
  end loop;
end $$;

commit;

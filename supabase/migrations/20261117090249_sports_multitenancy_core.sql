
create table if not exists public.sports_tenants (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(trim(name)) between 2 and 160),
 slug text not null unique check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
 status text not null default 'active' check(status in ('active','suspended','archived')),
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.sports_tenant_memberships (
 id uuid primary key default gen_random_uuid(),
 tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'member' check(role in ('owner','admin','coach','staff','member')),
 status text not null default 'active' check(status in ('invited','active','suspended','left')),
 created_at timestamptz not null default now(),
 unique(tenant_id,user_id), unique(id,tenant_id)
);
create index if not exists sports_memberships_user_status_idx on public.sports_tenant_memberships(user_id,status);
create index if not exists sports_memberships_tenant_role_idx on public.sports_tenant_memberships(tenant_id,role,status);
create table if not exists public.sports_members (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
 full_name text not null check(length(trim(full_name)) between 2 and 150), sport_type text, phone text,
 status text not null default 'active' check(status in ('active','inactive','suspended')),
 created_at timestamptz not null default now(), unique(id,tenant_id)
);
create index if not exists sports_members_tenant_created_idx on public.sports_members(tenant_id,created_at desc);
create table if not exists public.sports_events (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
 title text not null check(length(trim(title)) between 2 and 200), sport_type text, event_date timestamptz not null,
 location text, status text not null default 'scheduled' check(status in ('scheduled','ongoing','completed','cancelled')),
 created_at timestamptz not null default now(), unique(id,tenant_id)
);
create index if not exists sports_events_tenant_date_idx on public.sports_events(tenant_id,event_date);
create table if not exists public.sports_results (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
 member_id uuid not null, event_id uuid not null, score numeric(12,3), rank integer check(rank is null or rank>0),
 notes text check(notes is null or length(notes)<=2000), created_at timestamptz not null default now(),
 foreign key(member_id,tenant_id) references public.sports_members(id,tenant_id) on delete cascade,
 foreign key(event_id,tenant_id) references public.sports_events(id,tenant_id) on delete cascade
);
create index if not exists sports_results_tenant_created_idx on public.sports_results(tenant_id,created_at desc);
alter table public.sports_tenants enable row level security;
alter table public.sports_tenant_memberships enable row level security;
alter table public.sports_members enable row level security;
alter table public.sports_events enable row level security;
alter table public.sports_results enable row level security;
drop policy if exists sports_memberships_select_self on public.sports_tenant_memberships;
create policy sports_memberships_select_self on public.sports_tenant_memberships for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists sports_tenants_select_member on public.sports_tenants;
create policy sports_tenants_select_member on public.sports_tenants for select to authenticated using(exists(
 select 1 from public.sports_tenant_memberships m where m.tenant_id=sports_tenants.id and m.user_id=(select auth.uid()) and m.status='active'));
drop policy if exists sports_members_select_member on public.sports_members;
create policy sports_members_select_member on public.sports_members for select to authenticated using(exists(
 select 1 from public.sports_tenant_memberships m where m.tenant_id=sports_members.tenant_id and m.user_id=(select auth.uid()) and m.status='active'));
drop policy if exists sports_members_insert_staff on public.sports_members;
create policy sports_members_insert_staff on public.sports_members for insert to authenticated with check(exists(
 select 1 from public.sports_tenant_memberships m where m.tenant_id=sports_members.tenant_id and m.user_id=(select auth.uid()) and m.status='active' and m.role in('owner','admin','staff')));
drop policy if exists sports_events_select_member on public.sports_events;
create policy sports_events_select_member on public.sports_events for select to authenticated using(exists(
 select 1 from public.sports_tenant_memberships m where m.tenant_id=sports_events.tenant_id and m.user_id=(select auth.uid()) and m.status='active'));
drop policy if exists sports_events_insert_staff on public.sports_events;
create policy sports_events_insert_staff on public.sports_events for insert to authenticated with check(exists(
 select 1 from public.sports_tenant_memberships m where m.tenant_id=sports_events.tenant_id and m.user_id=(select auth.uid()) and m.status='active' and m.role in('owner','admin','staff','coach')));
drop policy if exists sports_results_select_member on public.sports_results;
create policy sports_results_select_member on public.sports_results for select to authenticated using(exists(
 select 1 from public.sports_tenant_memberships m where m.tenant_id=sports_results.tenant_id and m.user_id=(select auth.uid()) and m.status='active'));
drop policy if exists sports_results_insert_staff on public.sports_results;
create policy sports_results_insert_staff on public.sports_results for insert to authenticated with check(exists(
 select 1 from public.sports_tenant_memberships m where m.tenant_id=sports_results.tenant_id and m.user_id=(select auth.uid()) and m.status='active' and m.role in('owner','admin','staff','coach')));
grant usage on schema public to authenticated;
grant select on public.sports_tenants,public.sports_tenant_memberships,public.sports_members,public.sports_events,public.sports_results to authenticated;
grant insert on public.sports_members,public.sports_events,public.sports_results to authenticated;


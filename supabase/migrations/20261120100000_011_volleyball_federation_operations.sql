-- METATYA SPORT OS: shared federation operations foundation.
-- Additive tenant-scoped operational tables used by volleyball and future sport modules.
-- This migration is for isolated replay/preview only; never apply to live Supabase without separate approval.
begin;

create table if not exists public.sports_org_units (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
  parent_id uuid,
  unit_type varchar(24) not null check (unit_type in ('federation','province_board','county_board','association','club','academy','branch','department')),
  name varchar(160) not null check (char_length(trim(name)) between 2 and 160),
  code varchar(40),
  status varchar(20) not null default 'active' check (status in ('active','inactive','archived')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,tenant_id),
  unique (tenant_id,code),
  foreign key (parent_id,tenant_id) references public.sports_org_units(id,tenant_id) on delete restrict
);

create table if not exists public.sports_member_memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  member_id uuid not null,
  org_unit_id uuid,
  membership_number varchar(50),
  membership_type varchar(30) not null default 'athlete' check (membership_type in ('athlete','coach','referee','staff','honorary','other')),
  status varchar(20) not null default 'pending' check (status in ('pending','active','suspended','expired','cancelled')),
  valid_from date,
  valid_until date,
  fee_status varchar(20) not null default 'unknown' check (fee_status in ('unknown','unpaid','partial','paid','waived')),
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  notes varchar(1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,tenant_id),
  foreign key (member_id,tenant_id) references public.sports_members(id,tenant_id) on delete restrict,
  foreign key (org_unit_id,tenant_id) references public.sports_org_units(id,tenant_id) on delete restrict
);
create unique index if not exists sports_member_memberships_number_uq
  on public.sports_member_memberships(tenant_id,membership_number)
  where membership_number is not null;
create index if not exists sports_member_memberships_member_idx
  on public.sports_member_memberships(tenant_id,member_id,status,valid_until);

create table if not exists public.sports_staff_profiles (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  member_id uuid not null,
  staff_role varchar(24) not null check (staff_role in ('coach','assistant_coach','referee','scorer','trainer','medical_staff','administrator','other')),
  license_number varchar(60),
  grade varchar(40),
  status varchar(20) not null default 'active' check (status in ('active','inactive','suspended')),
  started_on date,
  ended_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,tenant_id),
  unique (tenant_id,member_id,staff_role),
  foreign key (member_id,tenant_id) references public.sports_members(id,tenant_id) on delete restrict
);

create table if not exists public.sports_staff_credentials (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  staff_profile_id uuid not null,
  credential_type varchar(40) not null,
  title varchar(160) not null,
  issuer varchar(160),
  credential_number varchar(80),
  issued_on date,
  expires_on date,
  verification_status varchar(20) not null default 'pending' check (verification_status in ('pending','verified','rejected','expired')),
  verified_by uuid references auth.users(id) on delete set null,
  verified_at timestamptz,
  document_key text,
  created_at timestamptz not null default now(),
  unique (id,tenant_id),
  foreign key (staff_profile_id,tenant_id) references public.sports_staff_profiles(id,tenant_id) on delete cascade,
  check (expires_on is null or issued_on is null or expires_on >= issued_on)
);

create table if not exists public.sports_member_guardian_consents (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  member_id uuid not null,
  guardian_user_id uuid references auth.users(id) on delete restrict,
  consent_scope varchar(40) not null check (consent_scope in ('membership','training','competition','travel','media','data_processing','talent_assessment')),
  status varchar(20) not null default 'pending' check (status in ('pending','granted','revoked','expired')),
  valid_from timestamptz,
  valid_until timestamptz,
  evidence_key text,
  captured_by uuid references auth.users(id) on delete set null,
  captured_at timestamptz not null default now(),
  revoked_at timestamptz,
  notes varchar(500),
  unique (id,tenant_id),
  foreign key (member_id,tenant_id) references public.sports_members(id,tenant_id) on delete restrict,
  check (valid_until is null or valid_from is null or valid_until > valid_from)
);

create table if not exists public.sports_training_programs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
  title varchar(160) not null,
  sport_type varchar(80) not null,
  age_group varchar(50),
  target_group varchar(100),
  coach_profile_id uuid,
  start_date date,
  end_date date,
  status varchar(20) not null default 'draft' check (status in ('draft','active','completed','cancelled')),
  description varchar(2000),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,tenant_id),
  foreign key (coach_profile_id,tenant_id) references public.sports_staff_profiles(id,tenant_id) on delete restrict,
  check (end_date is null or start_date is null or end_date >= start_date)
);

create table if not exists public.sports_training_sessions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  program_id uuid not null,
  title varchar(160) not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  facility_id uuid,
  coach_profile_id uuid,
  status varchar(20) not null default 'scheduled' check (status in ('scheduled','completed','cancelled')),
  notes varchar(1000),
  created_at timestamptz not null default now(),
  unique (id,tenant_id),
  foreign key (program_id,tenant_id) references public.sports_training_programs(id,tenant_id) on delete cascade,
  foreign key (coach_profile_id,tenant_id) references public.sports_staff_profiles(id,tenant_id) on delete restrict,
  check (ends_at is null or ends_at > starts_at)
);

create table if not exists public.sports_training_attendance (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  session_id uuid not null,
  member_id uuid not null,
  attendance_status varchar(20) not null check (attendance_status in ('present','absent','late','excused')),
  recorded_by uuid references auth.users(id) on delete set null,
  notes varchar(300),
  recorded_at timestamptz not null default now(),
  unique (session_id,member_id),
  foreign key (session_id,tenant_id) references public.sports_training_sessions(id,tenant_id) on delete cascade,
  foreign key (member_id,tenant_id) references public.sports_members(id,tenant_id) on delete restrict
);

create table if not exists public.sports_member_assessments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  member_id uuid not null,
  sport_type varchar(80) not null,
  assessment_type varchar(40) not null check (assessment_type in ('initial','technical','physical','performance','talent','periodic','other')),
  assessed_on date not null default current_date,
  assessor_profile_id uuid,
  guardian_consent_id uuid,
  score numeric(8,3),
  indicators jsonb not null default '{}'::jsonb check (jsonb_typeof(indicators)='object'),
  strengths text,
  development_areas text,
  recommendation text,
  review_status varchar(20) not null default 'draft' check (review_status in ('draft','reviewed','approved','superseded')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (id,tenant_id),
  foreign key (member_id,tenant_id) references public.sports_members(id,tenant_id) on delete restrict,
  foreign key (assessor_profile_id,tenant_id) references public.sports_staff_profiles(id,tenant_id) on delete restrict,
  foreign key (guardian_consent_id,tenant_id) references public.sports_member_guardian_consents(id,tenant_id) on delete restrict
);

create table if not exists public.sports_member_development_plans (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  member_id uuid not null,
  assessment_id uuid,
  title varchar(160) not null,
  goals jsonb not null default '[]'::jsonb check (jsonb_typeof(goals)='array'),
  start_date date,
  review_date date,
  status varchar(20) not null default 'draft' check (status in ('draft','active','on_track','needs_review','completed','cancelled')),
  assigned_coach_profile_id uuid,
  guardian_consent_id uuid,
  progress_notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,tenant_id),
  foreign key (member_id,tenant_id) references public.sports_members(id,tenant_id) on delete restrict,
  foreign key (assessment_id,tenant_id) references public.sports_member_assessments(id,tenant_id) on delete restrict,
  foreign key (assigned_coach_profile_id,tenant_id) references public.sports_staff_profiles(id,tenant_id) on delete restrict,
  foreign key (guardian_consent_id,tenant_id) references public.sports_member_guardian_consents(id,tenant_id) on delete restrict
);

create table if not exists public.sports_facilities (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
  name varchar(160) not null,
  facility_type varchar(40) not null check (facility_type in ('sports_hall','volleyball_court','shooting_range','gym','outdoor_field','office','other')),
  address varchar(300),
  capacity integer check (capacity is null or capacity > 0),
  status varchar(20) not null default 'active' check (status in ('active','maintenance','inactive')),
  accessibility_notes varchar(500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,tenant_id)
);

do $
begin
  if not exists (select 1 from pg_constraint where conname='sports_training_sessions_facility_tenant_fk') then
    alter table public.sports_training_sessions
      add constraint sports_training_sessions_facility_tenant_fk
      foreign key (facility_id,tenant_id) references public.sports_facilities(id,tenant_id) on delete restrict;
  end if;
end $;

create table if not exists public.sports_facility_bookings (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  facility_id uuid not null,
  purpose varchar(160) not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  booking_status varchar(20) not null default 'requested' check (booking_status in ('requested','approved','rejected','cancelled','completed')),
  requested_by uuid references auth.users(id) on delete set null,
  decided_by uuid references auth.users(id) on delete set null,
  decision_note varchar(500),
  created_at timestamptz not null default now(),
  unique (id,tenant_id),
  foreign key (facility_id,tenant_id) references public.sports_facilities(id,tenant_id) on delete restrict,
  check (ends_at > starts_at)
);
create index if not exists sports_facility_bookings_time_idx
  on public.sports_facility_bookings(tenant_id,facility_id,starts_at,ends_at);

create table if not exists public.sports_fee_invoices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  member_id uuid not null,
  membership_id uuid,
  invoice_number varchar(50) not null,
  description varchar(240) not null,
  amount_minor bigint not null check (amount_minor >= 0),
  currency char(3) not null default 'IRR',
  due_date date,
  invoice_status varchar(20) not null default 'issued' check (invoice_status in ('draft','issued','partially_paid','paid','void','overdue')),
  issued_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (id,tenant_id),
  unique (tenant_id,invoice_number),
  foreign key (member_id,tenant_id) references public.sports_members(id,tenant_id) on delete restrict,
  foreign key (membership_id,tenant_id) references public.sports_member_memberships(id,tenant_id) on delete restrict
);

create table if not exists public.sports_fee_payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  invoice_id uuid not null,
  amount_minor bigint not null check (amount_minor > 0),
  currency char(3) not null default 'IRR',
  payment_method varchar(20) not null check (payment_method in ('cash','bank_transfer','gateway','other')),
  external_reference varchar(120),
  payment_status varchar(20) not null default 'pending' check (payment_status in ('pending','confirmed','rejected','refunded')),
  received_at timestamptz,
  confirmed_by uuid references auth.users(id) on delete set null,
  notes varchar(500),
  created_at timestamptz not null default now(),
  unique (id,tenant_id),
  foreign key (invoice_id,tenant_id) references public.sports_fee_invoices(id,tenant_id) on delete restrict
);

create table if not exists public.sports_member_insurance (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  member_id uuid not null,
  provider varchar(160),
  policy_number varchar(80),
  coverage_type varchar(60) not null default 'sports_accident',
  valid_from date,
  valid_until date,
  insurance_status varchar(20) not null default 'pending' check (insurance_status in ('pending','active','expired','cancelled','rejected')),
  verified_by uuid references auth.users(id) on delete set null,
  verified_at timestamptz,
  evidence_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id,tenant_id),
  foreign key (member_id,tenant_id) references public.sports_members(id,tenant_id) on delete restrict,
  check (valid_until is null or valid_from is null or valid_until >= valid_from)
);

create table if not exists public.sports_tenant_settings (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
  setting_scope varchar(24) not null default 'tenant' check (setting_scope in ('tenant','org_unit','sport_module')),
  setting_key varchar(100) not null,
  setting_value jsonb not null default '{}'::jsonb,
  version integer not null default 1 check (version > 0),
  effective_from timestamptz not null default now(),
  changed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (tenant_id,setting_scope,setting_key,version)
);

create table if not exists public.sports_announcements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.sports_tenants(id) on delete cascade,
  title varchar(180) not null,
  body text not null,
  audience varchar(24) not null default 'all' check (audience in ('all','athletes','coaches','referees','staff','guardians')),
  publish_at timestamptz,
  expires_at timestamptz,
  status varchar(20) not null default 'draft' check (status in ('draft','published','archived')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (id,tenant_id),
  check (expires_at is null or publish_at is null or expires_at > publish_at)
);

create table if not exists public.sports_platform_audit_events (
  id bigint generated always as identity primary key,
  tenant_id uuid not null references public.sports_tenants(id) on delete restrict,
  actor_id uuid references auth.users(id) on delete set null,
  action varchar(20) not null check (action in ('INSERT','UPDATE','DELETE')),
  entity_type varchar(80) not null,
  entity_id uuid not null,
  occurred_at timestamptz not null default now(),
  request_id text
);

create index if not exists sports_org_units_tenant_parent_idx on public.sports_org_units(tenant_id,parent_id,status);
create index if not exists sports_staff_profiles_tenant_role_idx on public.sports_staff_profiles(tenant_id,staff_role,status);
create index if not exists sports_staff_credentials_expiry_idx on public.sports_staff_credentials(tenant_id,expires_on,verification_status);
create index if not exists sports_training_programs_tenant_status_idx on public.sports_training_programs(tenant_id,status,start_date);
create index if not exists sports_training_sessions_tenant_start_idx on public.sports_training_sessions(tenant_id,starts_at);
create index if not exists sports_training_attendance_member_idx on public.sports_training_attendance(tenant_id,member_id,recorded_at desc);
create index if not exists sports_member_assessments_member_idx on public.sports_member_assessments(tenant_id,member_id,assessed_on desc);
create index if not exists sports_member_development_plans_member_idx on public.sports_member_development_plans(tenant_id,member_id,status);
-- A talent assessment requires an explicitly granted, in-date consent linked to the same athlete.
create or replace function public.sports_validate_talent_assessment_consent()
returns trigger language plpgsql security definer set search_path=pg_catalog,public
as $
begin
  if new.assessment_type='talent' and not exists (
    select 1 from public.sports_member_guardian_consents c
    where c.id=new.guardian_consent_id and c.tenant_id=new.tenant_id
      and c.member_id=new.member_id and c.consent_scope='talent_assessment'
      and c.status='granted'
      and (c.valid_from is null or c.valid_from<=now())
      and (c.valid_until is null or c.valid_until>now())
  ) then
    raise exception 'talent assessment requires an active guardian consent for the same athlete' using errcode='42501';
  end if;
  return new;
end;
$;
revoke all on function public.sports_validate_talent_assessment_consent() from public,anon,authenticated;
create trigger sports_member_assessment_consent_check
before insert or update on public.sports_member_assessments
for each row execute function public.sports_validate_talent_assessment_consent();

-- If a development plan references consent, it must be granted, current and belong to that athlete.
create or replace function public.sports_validate_development_plan_consent()
returns trigger language plpgsql security definer set search_path=pg_catalog,public
as $
begin
  if new.guardian_consent_id is not null and not exists (
    select 1 from public.sports_member_guardian_consents c
    where c.id=new.guardian_consent_id and c.tenant_id=new.tenant_id
      and c.member_id=new.member_id and c.status='granted'
      and c.consent_scope in ('talent_assessment','data_processing')
      and (c.valid_from is null or c.valid_from<=now())
      and (c.valid_until is null or c.valid_until>now())
  ) then
    raise exception 'development plan consent must be active and linked to the same athlete' using errcode='42501';
  end if;
  return new;
end;
$;
revoke all on function public.sports_validate_development_plan_consent() from public,anon,authenticated;
create trigger sports_development_plan_consent_check
before insert or update on public.sports_member_development_plans
for each row execute function public.sports_validate_development_plan_consent();

-- Sensitive state transitions require owner/admin approval even for direct Data API calls.
create or replace function public.sports_enforce_sensitive_transitions()
returns trigger language plpgsql security definer set search_path=pg_catalog,private
as $
declare v_old jsonb:=to_jsonb(old); v_new jsonb:=to_jsonb(new); v_field text;
begin
  v_field:=case tg_table_name
    when 'sports_member_memberships' then 'status'
    when 'sports_staff_credentials' then 'verification_status'
    when 'sports_member_guardian_consents' then 'status'
    when 'sports_facility_bookings' then 'booking_status'
    when 'sports_fee_payments' then 'payment_status'
    when 'sports_member_insurance' then 'insurance_status'
    else null end;
  if v_field is not null and v_old->>v_field is distinct from v_new->>v_field
     and not private.has_active_tenant_role(new.tenant_id,array['owner','admin']::text[]) then
    raise exception 'sensitive status transition requires owner or admin approval' using errcode='42501';
  end if;
  return new;
end;
$;
revoke all on function public.sports_enforce_sensitive_transitions() from public,anon,authenticated;
create trigger sports_membership_status_approval
before update on public.sports_member_memberships
for each row execute function public.sports_enforce_sensitive_transitions();
create trigger sports_staff_credential_approval
before update on public.sports_staff_credentials
for each row execute function public.sports_enforce_sensitive_transitions();
create trigger sports_guardian_consent_approval
before update on public.sports_member_guardian_consents
for each row execute function public.sports_enforce_sensitive_transitions();
create trigger sports_facility_booking_approval
before update on public.sports_facility_bookings
for each row execute function public.sports_enforce_sensitive_transitions();
create trigger sports_fee_payment_approval
before update on public.sports_fee_payments
for each row execute function public.sports_enforce_sensitive_transitions();
create trigger sports_insurance_approval
before update on public.sports_member_insurance
for each row execute function public.sports_enforce_sensitive_transitions();

-- Only one active membership of a given type per athlete and tenant.
create unique index if not exists sports_member_memberships_one_active_uq
  on public.sports_member_memberships(tenant_id,member_id,membership_type)
  where status='active';

-- Prevent two approved bookings from occupying the same facility at overlapping times.
create or replace function public.sports_validate_facility_booking_overlap()
returns trigger language plpgsql security definer set search_path=pg_catalog,public
as $
begin
  if new.booking_status='approved' then
    perform pg_advisory_xact_lock(hashtextextended(new.facility_id::text,0));
    if exists (
      select 1 from public.sports_facility_bookings b
      where b.tenant_id=new.tenant_id and b.facility_id=new.facility_id
        and b.booking_status='approved' and b.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
        and tstzrange(b.starts_at,b.ends_at,'[)') && tstzrange(new.starts_at,new.ends_at,'[)')
    ) then
      raise exception 'facility already has an approved booking in this time range' using errcode='23P01';
    end if;
  end if;
  return new;
end;
$;
revoke all on function public.sports_validate_facility_booking_overlap() from public,anon,authenticated;
create trigger sports_facility_booking_overlap_check
before insert or update on public.sports_facility_bookings
for each row execute function public.sports_validate_facility_booking_overlap();


create index if not exists sports_fee_invoices_member_idx on public.sports_fee_invoices(tenant_id,member_id,invoice_status,due_date);
create index if not exists sports_fee_payments_invoice_idx on public.sports_fee_payments(tenant_id,invoice_id,payment_status);
create index if not exists sports_member_insurance_expiry_idx on public.sports_member_insurance(tenant_id,valid_until,insurance_status);
create index if not exists sports_announcements_publish_idx on public.sports_announcements(tenant_id,status,publish_at);

-- All operational tables enforce tenant row isolation.
do $$
declare t text;
begin
  foreach t in array array[
    'sports_org_units','sports_member_memberships','sports_staff_profiles','sports_staff_credentials',
    'sports_member_guardian_consents','sports_training_programs','sports_training_sessions',
    'sports_training_attendance','sports_member_assessments','sports_member_development_plans',
    'sports_facilities','sports_facility_bookings','sports_fee_invoices','sports_fee_payments',
    'sports_member_insurance','sports_tenant_settings','sports_announcements','sports_platform_audit_events'
  ] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('alter table public.%I force row level security',t);
  end loop;
end $$;

-- Standard tenant read/write policies. Sensitive records have narrower role sets.
do $$
declare
  t text;
  roles text[];
begin
  foreach t in array array[
    'sports_org_units','sports_member_memberships','sports_staff_profiles','sports_staff_credentials',
    'sports_member_guardian_consents','sports_training_programs','sports_training_sessions',
    'sports_training_attendance','sports_member_assessments','sports_member_development_plans',
    'sports_facilities','sports_facility_bookings','sports_fee_invoices','sports_fee_payments',
    'sports_member_insurance','sports_tenant_settings','sports_announcements'
  ] loop
    roles := array['owner','admin','staff']::text[];
    if t in ('sports_training_programs','sports_training_sessions','sports_training_attendance',
             'sports_member_assessments','sports_member_development_plans') then
      roles := array['owner','admin','staff','coach']::text[];
    end if;
    if t in ('sports_member_guardian_consents','sports_fee_invoices','sports_fee_payments','sports_member_insurance') then
      roles := array['owner','admin']::text[];
    end if;
    execute format('create policy %I on public.%I for select to authenticated using ((select private.has_active_tenant_role(tenant_id,%L::text[])))',
      t||'_tenant_select',t,roles);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select private.has_active_tenant_role(tenant_id,%L::text[])))',
      t||'_tenant_insert',t,roles);
    execute format('create policy %I on public.%I for update to authenticated using ((select private.has_active_tenant_role(tenant_id,%L::text[]))) with check ((select private.has_active_tenant_role(tenant_id,%L::text[])))',
      t||'_tenant_update',t,roles,roles);
    execute format('create policy %I on public.%I for delete to authenticated using ((select private.has_active_tenant_role(tenant_id,%L::text[])))',
      t||'_tenant_delete',t,roles);
  end loop;
end $$;

create policy sports_platform_audit_events_select
on public.sports_platform_audit_events for select to authenticated
using ((select private.has_active_tenant_role(tenant_id,array['owner','admin']::text[])));

grant select,insert,update,delete on
  public.sports_org_units,public.sports_member_memberships,public.sports_staff_profiles,
  public.sports_staff_credentials,public.sports_member_guardian_consents,public.sports_training_programs,
  public.sports_training_sessions,public.sports_training_attendance,public.sports_member_assessments,
  public.sports_member_development_plans,public.sports_facilities,public.sports_facility_bookings,
  public.sports_fee_invoices,public.sports_fee_payments,public.sports_member_insurance,
  public.sports_tenant_settings,public.sports_announcements to authenticated;
grant select on public.sports_platform_audit_events to authenticated;
revoke all on table
  public.sports_org_units,public.sports_member_memberships,public.sports_staff_profiles,
  public.sports_staff_credentials,public.sports_member_guardian_consents,public.sports_training_programs,
  public.sports_training_sessions,public.sports_training_attendance,public.sports_member_assessments,
  public.sports_member_development_plans,public.sports_facilities,public.sports_facility_bookings,
  public.sports_fee_invoices,public.sports_fee_payments,public.sports_member_insurance,
  public.sports_tenant_settings,public.sports_announcements,public.sports_platform_audit_events
from public,anon;
revoke insert,update,delete on public.sports_platform_audit_events from public,anon,authenticated;
revoke all on sequence public.sports_platform_audit_events_id_seq from public,anon;
grant usage,select on sequence public.sports_platform_audit_events_id_seq to authenticated;

-- Append-only, metadata-only audit events: never copy private athlete/financial payloads.
create or replace function public.sports_write_platform_audit_event()
returns trigger language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_tenant uuid; v_id uuid; v_action text;
begin
  if tg_op='DELETE' then
    v_tenant:=old.tenant_id; v_id:=old.id; v_action:='DELETE';
  else
    v_tenant:=new.tenant_id; v_id:=new.id; v_action:=tg_op;
  end if;
  insert into public.sports_platform_audit_events(tenant_id,actor_id,action,entity_type,entity_id)
  values(v_tenant,auth.uid(),v_action,tg_table_name,v_id);
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function public.sports_write_platform_audit_event() from public,anon,authenticated;

do $$
declare t text;
begin
  foreach t in array array[
    'sports_org_units','sports_member_memberships','sports_staff_profiles','sports_staff_credentials',
    'sports_member_guardian_consents','sports_training_programs','sports_training_sessions',
    'sports_training_attendance','sports_member_assessments','sports_member_development_plans',
    'sports_facilities','sports_facility_bookings','sports_fee_invoices','sports_fee_payments',
    'sports_member_insurance','sports_tenant_settings','sports_announcements'
  ] loop
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.sports_write_platform_audit_event()',
      t||'_audit_event',t);
  end loop;
end $$;

create or replace function public.sports_reject_platform_audit_mutation()
returns trigger language plpgsql set search_path=pg_catalog as $$
begin
  raise exception 'platform audit events are append-only' using errcode='42501';
end;
$$;
revoke all on function public.sports_reject_platform_audit_mutation() from public,anon,authenticated;
create trigger sports_platform_audit_immutable
before update or delete on public.sports_platform_audit_events
for each row execute function public.sports_reject_platform_audit_mutation();

commit;

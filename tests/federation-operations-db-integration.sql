\set ON_ERROR_STOP on
-- Uses synthetic tenant/member identities created by migration-replay-pre-security-seed.sql.
INSERT INTO auth.users(id) VALUES ('10000000-0000-4000-8000-000000000013');
INSERT INTO public.sports_tenant_memberships(tenant_id,user_id,role,status) VALUES
('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000013','staff','active');

-- Owner creates the shared federation records and approves only after a pending consent exists.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000010',false);

INSERT INTO public.sports_org_units(id,tenant_id,unit_type,name,code)
VALUES('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','province_board','Ilam Volleyball Board','ILAM-VB');

INSERT INTO public.sports_member_memberships(id,tenant_id,member_id,membership_number,membership_type,status)
VALUES('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000030','VB-ATH-001','athlete','pending');

INSERT INTO public.sports_staff_profiles(id,tenant_id,member_id,staff_role,license_number,grade)
VALUES('20000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000030','coach','COACH-001','A');

INSERT INTO public.sports_facilities(id,tenant_id,name,facility_type,capacity)
VALUES('20000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','Ilam Main Hall','sports_hall',500);

INSERT INTO public.sports_training_programs(id,tenant_id,title,sport_type,coach_profile_id,status)
VALUES('20000000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000001','Youth Volleyball Program','volleyball','20000000-0000-4000-8000-000000000003','active');

INSERT INTO public.sports_training_sessions(id,tenant_id,program_id,title,starts_at,ends_at,facility_id,coach_profile_id)
VALUES('20000000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000005','Session One',now()+interval '2 days',now()+interval '2 days 90 minutes','20000000-0000-4000-8000-000000000004','20000000-0000-4000-8000-000000000003');

INSERT INTO public.sports_training_attendance(tenant_id,session_id,member_id,attendance_status,recorded_by)
VALUES('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000030','present','10000000-0000-4000-8000-000000000010');

INSERT INTO public.sports_member_guardian_consents(id,tenant_id,member_id,guardian_user_id,consent_scope,status)
VALUES('20000000-0000-4000-8000-000000000007','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000030','10000000-0000-4000-8000-000000000011','talent_assessment','pending');

-- A pending consent must not authorize a talent assessment.
DO $$
BEGIN
  BEGIN
    INSERT INTO public.sports_member_assessments(tenant_id,member_id,sport_type,assessment_type,guardian_consent_id)
    VALUES('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000030','volleyball','talent','20000000-0000-4000-8000-000000000007');
    RAISE EXCEPTION 'pending guardian consent must not authorize talent assessment';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

UPDATE public.sports_member_guardian_consents SET status='granted'
WHERE id='20000000-0000-4000-8000-000000000007';

INSERT INTO public.sports_member_assessments(id,tenant_id,member_id,sport_type,assessment_type,assessor_profile_id,guardian_consent_id,score,indicators)
VALUES('20000000-0000-4000-8000-000000000008','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000030','volleyball','talent','20000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000007',82.5,'{"vertical_jump":"synthetic"}'::jsonb);

INSERT INTO public.sports_member_development_plans(id,tenant_id,member_id,assessment_id,title,goals,guardian_consent_id,assigned_coach_profile_id)
VALUES('20000000-0000-4000-8000-000000000009','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000030','20000000-0000-4000-8000-000000000008','Development Plan','[{"goal":"synthetic"}]'::jsonb,'20000000-0000-4000-8000-000000000007','20000000-0000-4000-8000-000000000003');

INSERT INTO public.sports_facility_bookings(tenant_id,facility_id,purpose,starts_at,ends_at,booking_status,requested_by,decided_by)
VALUES('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000004','League practice',now()+interval '5 days',now()+interval '5 days 2 hours','approved','10000000-0000-4000-8000-000000000010','10000000-0000-4000-8000-000000000010');

DO $$
BEGIN
  BEGIN
    INSERT INTO public.sports_facility_bookings(tenant_id,facility_id,purpose,starts_at,ends_at,booking_status)
    VALUES('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000004','Conflicting booking',now()+interval '5 days 30 minutes',now()+interval '5 days 90 minutes','approved');
    RAISE EXCEPTION 'overlapping approved facility booking must be rejected';
  EXCEPTION WHEN SQLSTATE '23P01' THEN NULL;
  END;
END $$;

INSERT INTO public.sports_fee_invoices(tenant_id,member_id,invoice_number,description,amount_minor,currency)
VALUES('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000030','INV-001','Synthetic membership fee',100000,'IRR');
INSERT INTO public.sports_fee_payments(tenant_id,invoice_id,amount_minor,payment_method,external_reference,payment_status)
SELECT '10000000-0000-4000-8000-000000000001',id,100000,'bank_transfer','SYNTHETIC-REF','pending'
FROM public.sports_fee_invoices WHERE invoice_number='INV-001';

INSERT INTO public.sports_member_insurance(tenant_id,member_id,provider,policy_number,coverage_type,insurance_status)
VALUES('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000030','Synthetic Insurer','POL-001','sports_accident','pending');

INSERT INTO public.sports_announcements(tenant_id,title,body,audience,status,created_by)
VALUES('10000000-0000-4000-8000-000000000001','Test notice','Synthetic notice body','all','draft','10000000-0000-4000-8000-000000000010');

INSERT INTO public.sports_tenant_settings(tenant_id,setting_scope,setting_key,setting_value,changed_by)
VALUES('10000000-0000-4000-8000-000000000001','sport_module','volleyball.season','{"season":"test"}'::jsonb,'10000000-0000-4000-8000-000000000010');

-- Owner can approve membership; this activates the membership lifecycle.
UPDATE public.sports_member_memberships SET status='active',approved_by='10000000-0000-4000-8000-000000000010',approved_at=now()
WHERE id='20000000-0000-4000-8000-000000000002';
RESET ROLE;

-- Staff may manage pending operational records, but cannot perform sensitive approval transitions.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000013',false);
DO $$
BEGIN
  BEGIN
    UPDATE public.sports_member_memberships SET status='suspended'
    WHERE id='20000000-0000-4000-8000-000000000002';
    RAISE EXCEPTION 'staff must not change membership approval state';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  IF (SELECT status FROM public.sports_member_memberships WHERE id='20000000-0000-4000-8000-000000000002')<>'active' THEN
    RAISE EXCEPTION 'denied staff transition changed membership state';
  END IF;
  IF (SELECT count(*) FROM public.sports_fee_invoices WHERE invoice_number='INV-001')<>0 THEN
    RAISE EXCEPTION 'staff can read private finance records';
  END IF;
  IF (SELECT count(*) FROM public.sports_training_programs WHERE id='20000000-0000-4000-8000-000000000005')<>1 THEN
    RAISE EXCEPTION 'staff cannot read authorized training records';
  END IF;
END $$;
RESET ROLE;

-- Coach may read training and assessment records, but may not read finance data.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000011',false);
DO $$
BEGIN
  IF (SELECT count(*) FROM public.sports_training_sessions WHERE id='20000000-0000-4000-8000-000000000006')<>1 THEN
    RAISE EXCEPTION 'coach cannot read assigned-tenant training sessions';
  END IF;
  IF (SELECT count(*) FROM public.sports_member_assessments WHERE id='20000000-0000-4000-8000-000000000008')<>1 THEN
    RAISE EXCEPTION 'coach cannot read authorized assessment records';
  END IF;
  IF (SELECT count(*) FROM public.sports_fee_payments)<>0 THEN
    RAISE EXCEPTION 'coach can read financial payment records';
  END IF;
END $$;
RESET ROLE;

-- Another tenant cannot read this tenant's records or insert into its tenant scope.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000020',false);
DO $$
BEGIN
  IF (SELECT count(*) FROM public.sports_org_units WHERE id='20000000-0000-4000-8000-000000000001')<>0 THEN
    RAISE EXCEPTION 'cross-tenant organization data leaked';
  END IF;
  BEGIN
    INSERT INTO public.sports_org_units(tenant_id,unit_type,name)
    VALUES('10000000-0000-4000-8000-000000000001','club','Cross Tenant Club');
    RAISE EXCEPTION 'cross-tenant organization insert must be rejected';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;

-- Authenticated users cannot write or mutate the platform audit ledger directly.
DO $$
BEGIN
  IF has_table_privilege('authenticated','public.sports_platform_audit_events','INSERT')
     OR has_table_privilege('authenticated','public.sports_platform_audit_events','UPDATE')
     OR has_table_privilege('authenticated','public.sports_platform_audit_events','DELETE') THEN
    RAISE EXCEPTION 'direct authenticated audit mutation privilege exists';
  END IF;
  IF (SELECT count(*) FROM public.sports_platform_audit_events
      WHERE entity_type='sports_member_memberships' AND entity_id='20000000-0000-4000-8000-000000000002')<2 THEN
    RAISE EXCEPTION 'membership audit history is incomplete';
  END IF;
END $$;

\echo 'Federation operations database integration tests passed.'

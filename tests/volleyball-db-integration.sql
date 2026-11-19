\set ON_ERROR_STOP on
INSERT INTO public.sports_tenants(id,name,slug,status) VALUES
('00000000-0000-4000-8000-000000000001','Tenant One','volleyball-tenant-one','active'),
('00000000-0000-4000-8000-000000000002','Tenant Two','volleyball-tenant-two','active');

INSERT INTO auth.users(id) VALUES
('00000000-0000-4000-8000-000000000010'),
('00000000-0000-4000-8000-000000000011'),
('00000000-0000-4000-8000-000000000012'),
('00000000-0000-4000-8000-000000000020');

INSERT INTO public.sports_tenant_memberships(tenant_id,user_id,role,status) VALUES
('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000010','owner','active'),
('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000011','coach','active'),
('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000012','referee','active'),
('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000020','owner','active');

INSERT INTO public.sports_members(id,tenant_id,full_name,sport_type,status) VALUES
('00000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-000000000001','Athlete One','volleyball','active'),
('00000000-0000-4000-8000-000000000031','00000000-0000-4000-8000-000000000001','Athlete Two','volleyball','active'),
('00000000-0000-4000-8000-000000000032','00000000-0000-4000-8000-000000000001','Athlete Three','volleyball','active');

-- Owner creates two teams and a third team not registered in the competition.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000010',false);
INSERT INTO public.sports_volleyball_teams(id,tenant_id,name,gender,created_by) VALUES
('00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000001','Home Team','mixed','00000000-0000-4000-8000-000000000010'),
('00000000-0000-4000-8000-000000000041','00000000-0000-4000-8000-000000000001','Away Team','mixed','00000000-0000-4000-8000-000000000010'),
('00000000-0000-4000-8000-000000000042','00000000-0000-4000-8000-000000000001','Unregistered Team','mixed','00000000-0000-4000-8000-000000000010');

INSERT INTO public.sports_volleyball_team_members(tenant_id,team_id,member_id,jersey_number,position) VALUES
('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000030',7,'setter'),
('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000041','00000000-0000-4000-8000-000000000031',9,'libero');

INSERT INTO public.sports_volleyball_competitions(id,tenant_id,name,format,season)
VALUES('00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000001','Test League','league','2026');

INSERT INTO public.sports_volleyball_competition_teams(tenant_id,competition_id,team_id,pool_code,seed) VALUES
('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000040','A',1),
('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000041','A',2);

INSERT INTO public.sports_volleyball_matches(id,tenant_id,competition_id,home_team_id,away_team_id,scheduled_at,best_of,created_by)
VALUES('00000000-0000-4000-8000-000000000060','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000041',now(),3,'00000000-0000-4000-8000-000000000010');

-- A competition match cannot contain a team that was not registered.
DO $$
BEGIN
  BEGIN
    INSERT INTO public.sports_volleyball_matches(tenant_id,competition_id,home_team_id,away_team_id,scheduled_at,best_of)
    VALUES('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000042',now(),3);
    RAISE EXCEPTION 'expected unregistered competition team to be rejected';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;

-- Match lineup snapshot must use a registered player from a match team.
INSERT INTO public.sports_volleyball_match_rosters(tenant_id,match_id,team_id,member_id,jersey_number,position,is_starter)
VALUES('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000060','00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000030',7,'setter',true);

DO $$
BEGIN
  BEGIN
    INSERT INTO public.sports_volleyball_match_rosters(tenant_id,match_id,team_id,member_id)
    VALUES('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000060','00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000032');
    RAISE EXCEPTION 'expected non-roster athlete to be rejected';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;

-- Official assignment requires an active referee membership in this tenant.
INSERT INTO public.sports_volleyball_match_officials(tenant_id,match_id,user_id,official_role,assigned_by)
VALUES('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000060','00000000-0000-4000-8000-000000000012','first_referee','00000000-0000-4000-8000-000000000010');

DO $$
BEGIN
  BEGIN
    INSERT INTO public.sports_volleyball_match_officials(tenant_id,match_id,user_id,official_role)
    VALUES('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000060','00000000-0000-4000-8000-000000000011','first_referee');
    RAISE EXCEPTION 'expected non-referee assignment to be rejected';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END $$;

RESET ROLE;

-- Cross-tenant reads are invisible; cross-tenant writes are denied.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000020',false);
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.sports_volleyball_teams WHERE tenant_id='00000000-0000-4000-8000-000000000001';
  IF n<>0 THEN RAISE EXCEPTION 'cross-tenant rows leaked'; END IF;
  BEGIN
    INSERT INTO public.sports_volleyball_teams(tenant_id,name)
    VALUES('00000000-0000-4000-8000-000000000001','Intruder Team');
    RAISE EXCEPTION 'expected cross-tenant write to be rejected';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;

-- Referee can submit a valid best-of-three 2-0 result atomically.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000012',false);
SELECT public.sports_volleyball_submit_score(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000060',
  '[{"home":25,"away":18},{"home":25,"away":20}]'::jsonb
);
DO $$
DECLARE s integer; status text;
BEGIN
  SELECT count(*) INTO s FROM public.sports_volleyball_match_sets WHERE match_id='00000000-0000-4000-8000-000000000060';
  SELECT result_status INTO status FROM public.sports_volleyball_matches WHERE id='00000000-0000-4000-8000-000000000060';
  IF s<>2 OR status<>'submitted' THEN RAISE EXCEPTION 'score submission was not atomic'; END IF;
  BEGIN
    PERFORM public.sports_volleyball_decide_result('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000060','approved',null);
    RAISE EXCEPTION 'referee must not approve results';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;

-- Owner approves; audit remains immutable to authenticated clients.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000010',false);
SELECT public.sports_volleyball_decide_result(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000060','approved',null
);
DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.sports_volleyball_result_audit WHERE match_id='00000000-0000-4000-8000-000000000060';
  IF n<>2 THEN RAISE EXCEPTION 'expected score and approval audit entries'; END IF;
  BEGIN
    UPDATE public.sports_volleyball_result_audit SET reason='tampered';
    RAISE EXCEPTION 'audit update should be denied';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    DELETE FROM public.sports_volleyball_result_audit;
    RAISE EXCEPTION 'audit delete should be denied';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;

\echo 'Volleyball database integration tests passed.'

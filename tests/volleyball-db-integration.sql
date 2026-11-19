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



-- Additional matches cover rejected-result resubmission and every legal set count.
INSERT INTO public.sports_volleyball_teams(id,tenant_id,name,gender)
VALUES('00000000-0000-4000-8000-000000000070','00000000-0000-4000-8000-000000000002','Tenant Two Team','mixed');

INSERT INTO public.sports_volleyball_matches(id,tenant_id,competition_id,home_team_id,away_team_id,scheduled_at,best_of,created_by)
VALUES
('00000000-0000-4000-8000-000000000061','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000041',now(),5,'00000000-0000-4000-8000-000000000010'),
('00000000-0000-4000-8000-000000000062','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000041',now(),5,'00000000-0000-4000-8000-000000000010'),
('00000000-0000-4000-8000-000000000063','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000041',now(),5,'00000000-0000-4000-8000-000000000010'),
('00000000-0000-4000-8000-000000000064','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000041',now(),3,'00000000-0000-4000-8000-000000000010');

-- A coach cannot submit an official result.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000011',false);
DO $$
BEGIN
  PERFORM public.sports_volleyball_submit_score(
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000061',
    '[{"home":25,"away":18},{"home":25,"away":20},{"home":25,"away":22}]'::jsonb
  );
  RAISE EXCEPTION 'coach must not submit official scores';
EXCEPTION WHEN insufficient_privilege THEN NULL;
END $$;
RESET ROLE;

-- Referee submits once; a duplicate pending submission is rejected.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000012',false);
SELECT public.sports_volleyball_submit_score(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000061',
  '[{"home":25,"away":18},{"home":25,"away":21},{"home":25,"away":20}]'::jsonb
);
DO $$
BEGIN
  PERFORM public.sports_volleyball_submit_score(
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000061',
    '[{"home":25,"away":18},{"home":25,"away":21},{"home":25,"away":20}]'::jsonb
  );
  RAISE EXCEPTION 'duplicate submission must be rejected';
EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
END $$;
RESET ROLE;

-- Owner rejects; the referee can then submit a corrected 3-1 result.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000010',false);
SELECT public.sports_volleyball_decide_result(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000061','rejected','لطفاً امتیاز ست چهارم بررسی شود'
);
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000012',false);
SELECT public.sports_volleyball_submit_score(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000061',
  '[{"home":25,"away":18},{"home":20,"away":25},{"home":25,"away":22},{"home":25,"away":20}]'::jsonb
);
RESET ROLE;

-- Best-of-five 3-0, 3-2 and best-of-three 2-1 paths.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000012',false);
SELECT public.sports_volleyball_submit_score(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000062',
  '[{"home":25,"away":18},{"home":25,"away":19},{"home":25,"away":20}]'::jsonb
);
SELECT public.sports_volleyball_submit_score(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000063',
  '[{"home":25,"away":18},{"home":20,"away":25},{"home":25,"away":22},{"home":23,"away":25},{"home":15,"away":12}]'::jsonb
);
SELECT public.sports_volleyball_submit_score(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000064',
  '[{"home":25,"away":18},{"home":20,"away":25},{"home":15,"away":12}]'::jsonb
);
RESET ROLE;

-- Approved results cannot be submitted again; direct score or result-state writes are blocked.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000012',false);
DO $$
BEGIN
  PERFORM public.sports_volleyball_submit_score(
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000060',
    '[{"home":25,"away":18},{"home":25,"away":20}]'::jsonb
  );
  RAISE EXCEPTION 'approved result must remain locked';
EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
END $$;
DO $$
BEGIN
  INSERT INTO public.sports_volleyball_match_sets(tenant_id,match_id,set_number,home_points,away_points)
  VALUES('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000064',4,25,20);
  RAISE EXCEPTION 'direct set insert must be denied';
EXCEPTION WHEN insufficient_privilege THEN NULL;
END $$;
DO $$
BEGIN
  UPDATE public.sports_volleyball_matches SET result_status='approved'
  WHERE id='00000000-0000-4000-8000-000000000064';
  RAISE EXCEPTION 'direct result-state update must be denied';
EXCEPTION WHEN insufficient_privilege THEN NULL;
END $$;
RESET ROLE;

-- A tenant cannot attach another tenant's team to its competition.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000010',false);
DO $$
BEGIN
  INSERT INTO public.sports_volleyball_competition_teams(tenant_id,competition_id,team_id)
  VALUES('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000050','00000000-0000-4000-8000-000000000070');
  RAISE EXCEPTION 'cross-tenant team reference must be rejected';
EXCEPTION WHEN foreign_key_violation THEN NULL;
END $$;
RESET ROLE;

-- The effective table grants deny anonymous access and direct set mutation.
DO $$
BEGIN
  IF has_table_privilege('anon','public.sports_volleyball_teams','SELECT') THEN
    RAISE EXCEPTION 'anon must not read volleyball tables';
  END IF;
  IF has_table_privilege('authenticated','public.sports_volleyball_match_sets','INSERT')
     OR has_table_privilege('authenticated','public.sports_volleyball_match_sets','UPDATE')
     OR has_table_privilege('authenticated','public.sports_volleyball_match_sets','DELETE') THEN
    RAISE EXCEPTION 'authenticated users must mutate match sets only through RPC';
  END IF;
  IF has_table_privilege('authenticated','public.sports_volleyball_matches','UPDATE') THEN
    RAISE EXCEPTION 'authenticated users must not directly change match result state';
  END IF;
END $$;

DO $$
DECLARE v_status text; v_sets integer; v_audit integer;
BEGIN
  SELECT result_status INTO v_status FROM public.sports_volleyball_matches
  WHERE id='00000000-0000-4000-8000-000000000061';
  SELECT count(*) INTO v_sets FROM public.sports_volleyball_match_sets
  WHERE match_id='00000000-0000-4000-8000-000000000061';
  SELECT count(*) INTO v_audit FROM public.sports_volleyball_result_audit
  WHERE match_id='00000000-0000-4000-8000-000000000061';
  IF v_status<>'submitted' OR v_sets<>4 OR v_audit<>3 THEN
    RAISE EXCEPTION 'rejected-result resubmission or audit history is inconsistent';
  END IF;
  SELECT count(*) INTO v_sets FROM public.sports_volleyball_match_sets
  WHERE match_id='00000000-0000-4000-8000-000000000062';
  IF v_sets<>3 THEN RAISE EXCEPTION 'best-of-five 3-0 set count is incorrect'; END IF;
  SELECT count(*) INTO v_sets FROM public.sports_volleyball_match_sets
  WHERE match_id='00000000-0000-4000-8000-000000000063';
  IF v_sets<>5 THEN RAISE EXCEPTION 'best-of-five 3-2 set count is incorrect'; END IF;
  SELECT count(*) INTO v_sets FROM public.sports_volleyball_match_sets
  WHERE match_id='00000000-0000-4000-8000-000000000064';
  IF v_sets<>3 THEN RAISE EXCEPTION 'best-of-three 2-1 set count is incorrect'; END IF;
END $$;

\echo 'Volleyball database integration tests passed.'

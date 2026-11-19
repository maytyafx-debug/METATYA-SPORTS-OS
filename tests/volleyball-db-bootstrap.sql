\set ON_ERROR_STOP on
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE auth.users (id uuid PRIMARY KEY);
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE
AS $$ SELECT NULLIF(current_setting('request.jwt.claim.sub', true),'')::uuid $$;

CREATE TABLE public.sports_tenants (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  created_by uuid
);
CREATE TABLE public.sports_tenant_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.sports_tenants(id),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  role text NOT NULL,
  status text NOT NULL
);
CREATE TABLE public.sports_members (
  id uuid PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES public.sports_tenants(id),
  full_name text NOT NULL,
  sport_type text,
  status text NOT NULL,
  UNIQUE (id,tenant_id)
);
CREATE TABLE public.sports_events (
  id uuid PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES public.sports_tenants(id),
  title text NOT NULL,
  UNIQUE (id,tenant_id)
);

CREATE OR REPLACE FUNCTION private.has_active_tenant_role(p_tenant_id uuid,p_roles text[])
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.sports_tenant_memberships m
    WHERE m.tenant_id=p_tenant_id AND m.user_id=auth.uid()
      AND m.status='active' AND m.role=ANY(p_roles)
  )
$$;

GRANT USAGE ON SCHEMA public,auth,private TO authenticated;
GRANT SELECT ON public.sports_tenant_memberships TO authenticated;

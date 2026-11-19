# METATYA EXPERT OS — Sports Module Factory Standard

**Status:** Architecture standard proposed for review. This document defines the mandatory build and release contract for every current and future sport module. It does not claim that every control described here is already implemented.

## 1. Product and module boundary

- **METATYA EXPERT OS** is the parent product and owns the shared platform contracts.
- Sports administration is a domain capability within the parent product. Each discipline (for example, volleyball) is a module, not a separately duplicated platform.
- A sport module owns only its discipline-specific rules, workflows, entities, validation, and user experience.
- Identity, organizations/tenants, memberships, permissions, athlete/member identity, consent, audit, files, notifications, reporting, integrations, billing, facilities, backup/recovery, and operational telemetry are shared capabilities. Implement each once and expose versioned contracts.
- Modules must not create parallel user accounts, tenant tables, permission engines, athlete directories, or duplicate admin consoles.

## 2. Shared core and extension contract

Every module must integrate through the same contracts:

1. **Identity and tenant context:** derive the user from the verified auth session. A client-supplied tenant identifier is a selector only; it never proves membership.
2. **Membership and roles:** use the central role/capability registry. Do not invent module-local role names or bypass shared authorization.
3. **Data ownership:** every tenant-owned row carries an immutable tenant key and is protected by database-enforced isolation, not only API filters.
4. **Module-owned records:** discipline tables reference shared tenant/member/event records through composite tenant-safe foreign keys. Do not duplicate personal identity fields.
5. **Privacy:** separate sensitive/private fields from general directory data. Apply least-privilege column grants and role-scoped RLS.
6. **Audit:** important state changes are attributable, append-only where required, and include actor, tenant, entity, action, timestamp, reason, and correlation identifier.
7. **Consent and minors:** guardian relationship, legal basis, purpose, scope, expiry/revocation, and access history are explicit before enabling self-service or sensitive-data processing for minors.
8. **Files and exports:** use shared authorization, malware scanning, retention, signed access, and export audit controls.
9. **Recovery:** every module declares its data dependencies, backup scope, recovery point/time objectives, and tested restore procedure. Restore drills run in isolation before release.
10. **Observability:** use common structured logs, metrics, trace/correlation IDs, alerting, and privacy-safe analytics.

## 3. Required module manifest

Each new discipline must provide a reviewed manifest before schema or UI work begins:

- module identifier, display name, owner, version, and compatibility range for shared contracts;
- discipline-specific entities and lifecycle/state machines;
- rules and validation sources, including effective date/version;
- API routes and events consumed/published;
- shared capabilities reused (with contract versions);
- role/capability matrix and row/column data classification;
- personal/sensitive/minor data inventory and consent requirements;
- audit events, retention, export and deletion/retention rules;
- migration list, foreign-key map, RLS policy map, indexes, RPC/function inventory;
- test plan: unit, API, cross-tenant negative cases, database/RLS, accessibility, E2E, backup/restore;
- rollout, rollback, feature-flag, monitoring, and support plan.

## 4. Migration and database release gate

A module migration is not eligible for deployment until all conditions pass:

1. Every previously applied migration has its exact immutable SQL source in version control or a verified archival artifact. Names, timestamps, checksums, and ledger entries reconcile exactly.
2. A clean database can be built from the complete migration chain; the resulting schema is compared with the target baseline (tables, columns, constraints, indexes, policies, grants, functions, triggers, extensions, and RLS/FORCE RLS flags).
3. Migrations are forward-only, scoped, reviewed, and non-destructive by default. No destructive DDL, data rewrite, broad grant, or irreversible transformation without a separately approved plan and verified recovery point.
4. The migration is applied to an isolated database first. Test fresh install, upgrade from the supported baseline, repeatability where appropriate, failure behavior, rollback/recovery, and compatibility with the deployed application.
5. Never mark a migration tested based only on mocked PostgreSQL CI. At least one real isolated Supabase-compatible integration run must exercise the relevant RLS, grants, RPCs, triggers, and constraints.
6. A production migration is a separate release action with an explicit change summary, verified backup/recovery plan, maintenance/impact assessment, and owner approval.

## 5. Mandatory authorization and isolation tests

For every table, view, RPC, function, storage path, and API route, test both allowed and denied cases:

- unauthenticated and anonymous access;
- authenticated user with no tenant membership;
- suspended/inactive membership and suspended tenant;
- each allowed role and each explicitly denied role;
- tenant A attempting to read, insert, update, delete, or reference tenant B data;
- forged tenant headers and mismatched tenant/member/event foreign keys;
- attempts to change tenant identity or membership identity;
- last-owner removal and privilege escalation;
- private-column access through direct Data API, views, RPCs, exports, and logs;
- function EXECUTE grants for PUBLIC, anon, authenticated, and service roles;
- append-only audit integrity and unauthorized corrections.

RLS and grants are independent defense layers. Passing API authorization tests does not replace database tests.

## 6. First-owner onboarding and account lifecycle

- Public signup must not implicitly create a privileged tenant owner.
- First-owner bootstrap must be controlled, authenticated, atomic, tenant-scoped, and protected against replay/claim races.
- The bootstrap operation must bind the owner to auth.uid() and must not accept a caller-supplied user ID as proof of identity.
- Do not put service-role credentials in browser bundles, public environment variables, client logs, or preview builds.
- Email verification, callback URLs, session refresh, invitation acceptance, membership suspension, owner transfer, and account recovery must be tested.
- A user with no active tenant receives a safe onboarding state; no data-entry APIs become available until a valid membership exists.

## 7. Preview and deployment isolation

- Pull-request previews use a dedicated non-production Supabase project/branch and synthetic data only.
- Preview configuration is scoped to deploy-preview context. Production environment variables and Auth configuration remain unchanged.
- A preview must identify its source commit, branch, database target, and access-control status.
- Keep previews behind team SSO or equivalent access control until security and E2E verification pass.
- Verify the actual repository connection, build commit, deploy logs, environment context, and runtime database URL before accepting a preview.
- A green Netlify build proves only that a deploy built; it does not prove login, database connectivity, tenant isolation, or business workflows.
- Public production URLs are issued only after production release gates and user acceptance tests pass.

## 8. CI and quality gates

Every module PR must run:

- formatting, type checking, linting, static analysis, dependency and secret scanning;
- unit and domain-rule tests;
- API authorization tests;
- clean PostgreSQL migration replay;
- positive and negative RLS/grant/RPC integration tests with at least two synthetic tenants;
- production build and preview build;
- browser E2E for signup/login, onboarding, role-based navigation, core module workflow, refresh/session expiry, and error states;
- accessibility and RTL/localization checks where applicable;
- backup/restore drill evidence for affected data.

CI reports must identify the exact commit and clearly distinguish mocked tests from real service integration tests.

## 9. New-discipline delivery sequence

1. Review the shared-core contracts and complete the module manifest.
2. Model discipline-specific rules and lifecycle; reject duplicate shared entities.
3. Implement domain logic and unit tests without persistence.
4. Add tenant-safe schema, constraints, indexes, RLS, grants, and audit events.
5. Run isolated migration replay and real database security tests.
6. Implement APIs using shared auth, tenant resolution, permissions, and audit middleware.
7. Implement UI using shared navigation, forms, design system, and accessibility patterns.
8. Connect an isolated preview environment and run synthetic multi-tenant E2E.
9. Complete backup/restore, observability, operational runbook, and acceptance evidence.
10. Submit a release decision package. Merge, production migration, and public launch remain separate approval gates.

## 10. Volleyball application of this standard

Volleyball must consume the shared organization, identity, athlete/member, role, audit, consent, notification, facility, and reporting contracts. Its module boundary is limited to volleyball-specific teams/rosters, competition formats, fixtures, lineups, officials, scoring, result approval, and volleyball standings. Shared capabilities must be implemented in the core rather than copied into the volleyball module.

## 11. Release evidence record

Every module release must publish an evidence table with: requirement, implementation reference, test command/run, exact commit, result, environment, and remaining limitation. Use only observed evidence. “Designed”, “implemented”, “CI passed”, “isolated integration passed”, “preview verified”, and “production operational” are distinct states and must never be conflated.

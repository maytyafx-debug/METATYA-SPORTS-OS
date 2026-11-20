# METATYA SPORT OS — Platform Owner Implementation Plan

**Document:** Platform Owner Implementation Plan  
**Version:** 1.0  
**Status:** Proposed implementation blueprint; no application or database changes authorized  
**Repository baseline reviewed:** `main` at `c8e7af012b0ca6d3059c8876b1d3741c7f14e54e`  
**Governance specification:** `docs/PLATFORM_OWNER_GOVERNANCE_V1.md`  
**Review date:** 2026-11-20

## 1. Executive decision

The current system has tenant-scoped authorization but no implemented global Platform Owner principal. The next implementation must add one authoritative global owner identity without fabricating tenant memberships and without weakening tenant isolation for every other principal.

The target is one primary Platform Owner bound to the verified Supabase Auth UUID for the founder. The UUID observed in the current Auth project is:

`3a62811d-d3b0-4d82-b266-cba7e160e30c`

This is a bootstrap candidate only. Re-verify the UUID and account ownership immediately before provisioning. Do not use email, mutable profile fields, JWT user metadata, client flags, headers, or tenant role values as the permanent authority source.

**This plan is not a migration and does not authorize live changes.** The implementation is to be developed in a separate branch and verified against synthetic fixtures in isolated PostgreSQL/Supabase-compatible environments.

## 2. Evidence reviewed

### 2.1 Repository implementation on main

The following source files were inspected:

- `middleware.ts`: validates the Supabase session with `auth.getUser()`; it protects the root page and redirects unauthenticated users. It does not resolve platform roles.
- `lib/supabase/server.ts`: creates a cookie-backed server client using the public publishable/anon key. No service-role client is present in this file.
- `lib/tenancy/resolve-tenant.ts`: requires an active membership for the requested tenant. A user with no membership in the target tenant is denied.
- `lib/tenancy/permissions.ts`: defines tenant-only roles and capabilities; there is no Platform Owner principal or global capability contract.
- `app/api/tenancy/route.ts`: lists only the authenticated user's active tenant memberships.
- Twelve sports API route files call `resolveTenant` and scope database queries/RPCs to `tenantId`: events, members, results, volleyball competitions, competition teams, standings, matches, match officials, match rosters, match score/approval, volleyball teams, and team members.
- `app/platform/page.tsx`: a public architecture/marketing page, not an authenticated global administration console.
- Existing RLS and RPC foundations are in the timestamped migrations and tests listed below.

The existing API pattern is a useful tenant-isolation foundation, but it cannot satisfy global owner access. Updating only the UI or middleware would not be sufficient: PostgreSQL RLS, RPCs, storage, exports, and background work must enforce the same authority model.

### 2.2 Repository migrations and tests

The repository contains these proposed tenant-security components:

- `20261119120000_sports_tenant_security_alignment.sql`: creates the private schema and `private.has_active_tenant_role`, then defines tenant-scoped RLS and private member-data separation.
- `20261119150000_sports_member_history_hardening.sql`: enables and forces RLS on member history and adds tenant-role policies.
- `20261119180000_010_volleyball_operational_module.sql`: creates the volleyball operational tables, RLS, RPCs, and result audit.
- `20261119200000_016_member_history_audit_and_private_grant_revoke.sql`: closes residual private-column grants and adds append-only member-history triggers.
- `tests/migration-replay-security-assertions.sql` and `tests/volleyball-db-integration.sql`: provide synthetic-data security and operational regression assertions.

These files are repository candidates, not proof of production application.

### 2.3 Live Supabase read-only verification

The live project was checked using read-only project metadata, table/migration listings, advisors, and SELECT queries. No DDL, DML, grant, policy, role, Auth, or setting change was performed.

Observed state at review time:

| Check | Live evidence |
|---|---|
| Project status | `ACTIVE_HEALTHY`, PostgreSQL 17 |
| Migration ledger | Ends at `20261119105357` (`009_sports_member_history_repair`) |
| Platform-owner registry | No matching table/relation in public or private |
| Private schema | Not present |
| `private.has_active_tenant_role` | Not present |
| `sports_member_private` | Not present |
| Active memberships | 2 admin, 1 member, 0 owner |
| Member rows with phone or birth date | 2 |
| `sports_member_history` rows | 0 |
| `sports_member_history` RLS | Enabled; FORCE RLS is false |
| Core tenant tables | RLS enabled and forced |
| Sensitive source-column grants | `authenticated` still has INSERT, SELECT, and UPDATE on `phone` and `birth_date` |
| Founder Auth UUID | The UUID above exists in `auth.users` |

The live migration ledger does **not** yet include the proposed tenant-security alignment, member-history hardening, volleyball module, or 016 history/grant hardening migrations. The repository's successful migration replay tests therefore must not be interpreted as those changes being live.

The live security advisor reported three RLS-enabled/no-policy findings on legacy tables `data_bank`, `finance_ledger`, and `monetization_opportunities`, plus disabled leaked-password protection. These are outside this implementation scope and must not be modified as part of Platform Owner work without a separate review.

## 3. Target authorization model

### 3.1 Principals

- **Platform Owner:** exactly one primary global owner identity; global read and management authority across tenants and modules.
- **Tenant Owner:** authority only within the tenant whose ownership is recorded.
- **Tenant Admin and operational roles:** explicitly delegated tenant/resource capabilities.
- **Platform operators:** not introduced in this phase. Any future delegation requires a separate governance decision and narrow, explicit capabilities; it must not create a second Platform Owner.

Platform Owner is a platform principal, not a tenant role. Do not add a fake `owner` membership for the founder to every tenant.

### 3.2 Logical registry

Design one protected relation in the non-exposed `private` schema (proposed name: `private.platform_owners`). Logical fields:

- singleton owner slot (constrained so at most one primary owner row can exist);
- `user_id uuid` as primary identity, referencing `auth.users(id)` with restrictive deletion behavior;
- active/disabled status;
- created timestamp and creator identity;
- optional provenance/reference for the approved bootstrap or transfer event.

Do not store credentials, access tokens, secrets, or unnecessary profile data in this registry. No authenticated user may directly insert, update, or delete registry rows. Provisioning and transfer remain controlled, reviewed governance operations.

### 3.3 Database authorization helpers

Keep the existing tenant-role helper semantics for ordinary tenant authorization. Add a narrowly scoped owner predicate, proposed as `private.is_platform_owner()`, with these constraints:

- no caller-supplied user UUID parameter; resolve identity only from `auth.uid()`;
- return false for a null or unauthenticated identity;
- read only the protected singleton registry;
- fixed safe `search_path`, fully qualified object references, no dynamic SQL;
- use `SECURITY DEFINER` only if required to read the protected registry without exposing it or creating RLS recursion; otherwise prefer invoker rights;
- revoke execution from `PUBLIC` and `anon`; grant only the minimum required authenticated role;
- function owner and table grants must be explicitly reviewed;
- never expose registry rows through the Data API.

Then add a single centralized policy predicate (proposed `private.has_platform_or_active_tenant_role(tenant_id, roles)`) for tenant-owned records. It should return true for a verified Platform Owner or for an active tenant member whose role matches the requested scope. The owner exception must not bypass business invariants or audit immutability.

Do not blindly add an owner OR condition to every policy. Review each table by operation and data sensitivity. In particular:
- tenant data tables may permit global owner read and authorized management;
- audit/history tables may permit global owner read but must remain non-updateable/non-deletable by application principals;
- owner-registry and ownership-transfer tables must remain unavailable for direct client mutation;
- private athlete fields must be accessible only through explicitly audited access paths;
- storage object policies and RPC execute grants require their own review.

### 3.4 Authorization evaluation

All server/API operations use one shared contract:

1. Validate the Supabase session using `auth.getUser()`.
2. Resolve Platform Owner status from the authoritative registry.
3. Resolve the requested tenant from a validated route parameter or tenant selector.
4. If Platform Owner, allow access to that tenant without requiring a membership row; otherwise require active membership and tenant status.
5. Evaluate the operation-specific capability and resource scope.
6. Apply data-sensitivity, consent, retention, workflow, and immutable-record constraints.
7. Record privileged and sensitive actions in the audit trail.
8. Default to deny on missing identity, ambiguous tenant context, failed registry lookup, or authorization service error.

A Platform Owner request to a tenant-scoped endpoint must still identify the target tenant. Do not silently turn an ordinary tenant endpoint into an unbounded cross-tenant export. Provide separate, explicit platform-level endpoints for global inventory and cross-tenant reporting.

## 4. Application integration plan

### 4.1 Shared server authorization layer

Introduce a server-only authorization module, for example:

- `lib/platform/resolve-platform-principal.ts`
- `lib/authorization/resolve-access-context.ts`
- `lib/authorization/capabilities.ts`

Use a discriminated access-context type so handlers cannot accidentally assume a tenant ID exists for a global request. Keep `resolveTenant` backward-compatible initially or migrate all callers atomically; do not create mixed, ambiguous authorization semantics.

For tenant-scoped routes:
- normal tenant users continue through active membership and capability checks;
- Platform Owner can select an existing active tenant without membership;
- every read/write remains explicitly filtered by the selected tenant ID;
- tenant ID remains server-validated and is never accepted as proof of authority.

For platform-level routes, introduce a separate `/api/platform/*` surface with explicit global capabilities, pagination, safe filters, no-store caching, and audit events. Do not reuse tenant APIs for unbounded data extraction.

### 4.2 Route coverage

The following existing route families must be migrated and tested as one coordinated change:

- `/api/tenancy`
- `/api/sports/events`
- `/api/sports/members`
- `/api/sports/results`
- `/api/sports/volleyball/competitions`
- `/api/sports/volleyball/competitions/[competitionId]/teams`
- `/api/sports/volleyball/competitions/[competitionId]/standings`
- `/api/sports/volleyball/matches`
- `/api/sports/volleyball/matches/[matchId]/officials`
- `/api/sports/volleyball/matches/[matchId]/rosters`
- `/api/sports/volleyball/matches/[matchId]/score`
- `/api/sports/volleyball/teams`
- `/api/sports/volleyball/teams/[teamId]/members`

The logout route remains authentication/session functionality, not an owner authorization route. Middleware remains a session/navigation layer; it must not become the sole security boundary.

### 4.3 Sensitive athlete data

The live database still has `phone` and `birth_date` on `public.sports_members`, and authenticated column grants remain. The repository's proposed private-table migration has not been applied live.

Before enabling Platform Owner access to these fields:
- reconcile and test the private-field copy in an isolated database;
- verify exact source and destination row counts and values using synthetic data;
- revoke authenticated access to the original sensitive columns;
- expose private fields through a narrowly scoped server/database access path that emits a durable access event;
- ensure ordinary tenant roles retain only their approved access;
- preserve consent, lawful-purpose, retention, and guardian requirements for minors.

Global authority does not remove those constraints.

## 5. Audit and integrity model

The existing member-history and volleyball-result audit patterns are useful but are not a complete platform-wide audit system.

Add or map a platform audit event model covering at least:
- actor UUID and effective principal type;
- action, target type/ID, tenant ID (nullable for platform-level actions);
- timestamp and correlation/request ID;
- reason/reference for sensitive or high-impact access;
- outcome, including denied privileged attempts;
- before/after references for mutations, without copying secrets or unnecessary private payloads.

Platform Owner must be able to inspect all audit records. Application principals, including Platform Owner, must not silently update/delete audit events. Corrections are new linked events. Define a separately controlled database break-glass procedure for infrastructure-level administrators; such access must itself be externally/evidentially logged and is not an ordinary application permission.

Sensitive reads (especially private athlete data), cross-tenant exports, role changes, owner bootstrap/transfer, tenant suspension, and recovery operations must emit audit events.

## 6. Test and verification matrix

All fixtures must be synthetic and must not contain real minor-athlete data.

| Area | Required positive tests | Required negative tests |
|---|---|---|
| Owner identity | Verified owner UUID resolves globally | Forged user metadata, email, headers, body, or client flags do not grant owner |
| Tenant scope | Owner accesses tenant B without membership | Tenant A owner/admin cannot access tenant B |
| Memberships | Platform Owner can inspect/manage tenant membership | Tenant admin cannot create/modify global owner registry |
| API | Owner can use all approved tenant-scoped routes with explicit tenant selection | Missing/invalid tenant and unauthorized capabilities are denied |
| RLS | Owner policies work across every current sports and volleyball table | Other principals remain tenant-isolated |
| RPC | Owner can invoke only approved operations | Forged tenant IDs and unauthenticated calls fail |
| Storage | Owner global access is explicit and audited | Cross-tenant object paths are denied to tenant principals |
| Private data | Owner accesses private fields through audited path | Unauthorized roles cannot select source/private fields |
| Audit | Owner can read platform-wide audit events | App roles, including owner, cannot mutate/delete audit evidence |
| Revocation | Disabled owner loses authority within documented freshness window | Stale session/claims cannot preserve revoked access indefinitely |
| Recovery | Restore preserves owner registry, memberships, RLS, audit and tenant boundaries | Partial/invalid restore cannot silently promote or remove owner |
| Regression | Existing tenant roles and volleyball workflows remain correct | No role escalation or tenant isolation regression |

Required checks:
- TypeScript, ESLint, unit tests, dependency audit, production build;
- full timestamped migration replay on ephemeral PostgreSQL;
- RLS and grant assertions for all relevant tables;
- API authorization integration tests for every route above;
- RPC, storage, view, export, and background-job authorization tests;
- Supabase security/performance advisors;
- isolated restore drill and post-restore authorization tests.

CI success alone is not proof of live database correctness.

## 7. Ordered implementation work packages

1. **Freeze baseline:** preserve the reviewed main commit and current live migration ledger evidence.
2. **Resolve migration parity:** restore/reconcile historical migration sources and decide separately which pending tenant-security/volleyball migrations are required. Do not combine unrelated migrations into the owner bootstrap.
3. **Complete tenant security prerequisites:** in isolation, validate private member-data separation, column grants, history FORCE RLS, and the volleyball migration chain.
4. **Design owner registry and helper:** finalize schema, singleton constraint, function ownership/grants, RLS predicates, revocation behavior, and audit events.
5. **Implement database layer in a new branch:** add owner registry and centralized helpers as reviewed migration files; update all relevant policies without broadening audit mutation rights.
6. **Implement application layer:** shared access context, route coverage, explicit platform endpoints, owner UI shell, and audited sensitive-data access.
7. **Run full isolated verification:** synthetic owner plus two tenant principals, with the owner deliberately having no membership in the second tenant.
8. **Review complete diff and evidence:** document changed objects, grant/policy matrix, route coverage, test results, and rollback/forward-recovery plan.
9. **Obtain explicit approval:** present the exact migration set and impact. A separate approval is required for any live backup procedure, live migration, production deploy, or PR merge.
10. **Live rollout only after gates:** independently stored and verified full backup, controlled migration, immediate read-back checks, owner login/access test, tenant isolation regression, and separate production deployment approval.

## 8. Current blockers and non-goals

### Blockers before live provisioning

- Live project has no private schema, owner registry, or owner helper.
- Live migration ledger has not applied the repository's tenant-security alignment, private member-data separation, volleyball module, or 016 audit/grant hardening migrations.
- Two live member rows still contain phone/birth-date data in the source table, and authenticated column grants remain.
- Member-history RLS is enabled but not forced.
- Supabase project is on the Free plan; a separately stored and verified backup is mandatory before live DDL. Do not assume automatic daily backup or PITR.
- The owner UUID exists in Auth but must be re-verified immediately before controlled bootstrap.

### Explicit non-goals for this phase

- No second Platform Owner or general platform-operator delegation.
- No tenant membership fabrication for the Platform Owner.
- No client-side role claims or service-role key in the browser.
- No broad unfiltered export endpoint.
- No weakening of audit immutability, tenant identity constraints, ownership continuity, consent, or minor-data protections.
- No live migration, role assignment, data rewrite, Auth setting change, secret change, production deployment, or PR merge.

## 9. Acceptance definition

The Platform Owner implementation is not complete until all of the following are evidenced:

1. One verified owner identity is registered from the approved Auth UUID.
2. The owner can read and manage every approved tenant/module without membership in each tenant.
3. Every ordinary tenant principal remains strictly tenant-scoped.
4. All APIs, RLS policies, RPCs, storage paths, exports, and background jobs use the same authorization contract.
5. Sensitive data access and privileged actions are auditable.
6. Audit/history records cannot be silently altered or erased by application principals.
7. Revocation, recovery, and ownership transfer are tested.
8. Existing tenant and sports-module regression suites pass.
9. The live database state is verified separately after any later approved rollout.

**Status:** Evidence review and design plan only. No application code, SQL, live database, Auth role, secret, or production setting was changed by this document.

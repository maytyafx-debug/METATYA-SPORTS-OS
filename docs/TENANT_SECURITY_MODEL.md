# METATYA Sports OS — Tenant Security Contract

**Status:** Implemented in code/migration proposal; not yet deployed or runtime-verified.
**Migration order:** Apply 006 first, then 007, only in an isolated Supabase-compatible environment before production approval.

## Canonical tenant roles

| Role | Members | Events | Results | Membership administration |
|---|---|---|---|---|
| owner | read/create/update/delete | read/create/update/delete | read/create/update/delete | manage |
| admin | read/create/update/delete | read/create/update | read/create/update | manage; cannot create or remove owners |
| referee | read | read | read/create | none |
| coach | read | read/create | read/create | none |
| staff | read/create/update | read/create | read/create | none |
| member | no general member-record access | read | read | none |

The member role does not receive access to the general sports_members directory because the current data model has no verified link from a membership account to a specific athlete record. A future athlete portal must add an explicit, consent-aware account-to-athlete relationship before enabling self-service access.

## Enforcement layers

1. The Next.js API resolves the authenticated Supabase user on every request.
2. The requested x-tenant-id is only a selector; it is never trusted as proof of membership.
3. The resolver requires an active membership and an active tenant.
4. API role checks use lib/tenancy/permissions.ts.
5. PostgreSQL RLS independently checks the same tenant and role contract.
6. Migration 007 forces RLS on all five tenant tables.
7. A private, fixed-search-path helper is used by policies to avoid recursive membership-table RLS checks. Its execution is revoked from PUBLIC and anon and granted only to authenticated.
8. Tenant identity on sports records and the identity pair on memberships are immutable.
9. A tenant cannot lose its last active owner through membership update/delete.

## Important boundaries

- Tenant creation and first-owner bootstrap are not exposed as a public API in this change. They remain a controlled operator/onboarding task.
- No service-role key is introduced into browser code.
- This change does not implement result approval, full audit logging, invitations/email delivery, per-event referee assignments, or a complete athlete self-service portal. Those remain separate, explicitly scoped work.
- The RLS contract permits a referee to read tenant-wide member/event/result records and insert results. If referees must be restricted to assigned events, a future event-assignment relation and policies are required before that workflow is enabled.
- Admin can manage non-owner memberships but cannot create, demote, or delete an owner. Only an owner can administer owner membership.
- Admin cannot delete events or results. Owner-only deletion is intentionally conservative.

## Verification gates

- npm run typecheck
- npm run lint
- npm run test:security
- npm run build
- Isolated PostgreSQL/Supabase integration tests for positive and negative RLS cases
- Restore drill in a compatible isolated environment
- Production migration review and explicit owner approval

A successful TypeScript/CI run is not proof of database policy correctness. Do not mark this contract operational until the isolated RLS tests and restore drill pass.

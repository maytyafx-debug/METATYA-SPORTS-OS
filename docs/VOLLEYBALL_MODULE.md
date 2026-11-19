# Volleyball Module — Operational Scope

**Parent product:** METATYA Sports OS  
**Module boundary:** Volleyball rules, team rosters, fixtures, match scoring and result approval. Shared identity, tenants, athlete directory, roles, audit and platform operations remain in Sports OS.

## Delivery status (2026-11-19)

| Capability | State | Evidence / limitation |
|---|---|---|
| Volleyball domain score validation | Implemented | Best-of-3 and best-of-5; points and two-point margin |
| Tenant-scoped team records | Implemented in branch | Migration 010; not yet applied to live database |
| Team roster with jersey and position | Implemented in branch | Uses shared Sports OS athlete directory |
| Fixture scheduling | Implemented in branch | Home/away teams, venue, date/time, match format |
| Match set score submission | Implemented in branch | Role restricted; score audit rows; submitted status |
| Result approval / rejection | Implemented in branch | Owner/admin only; approval timestamp and actor |
| Live score updates, substitutions, libero tracking | Planned | Requires event-level scoring and lineup workflow |
| Tournament brackets, pools, round-robin standings | Planned | Competition engine and standings rules needed |
| Training plans, attendance and development | Shared-platform backlog | Must be implemented once in Sports OS, not duplicated here |
| Coach/referee licensing and assignment | Shared-platform backlog | Qualification and conflict-of-interest workflow required |
| Finance, membership fees, insurance, facilities booking | Shared-platform backlog | Shared Economy & Facilities area |
| Athlete self-service portal and guardian consent | Shared-platform backlog | Depends on shared portal, privacy and minor safeguards |
| Analytics, talent pathways and AI assistance | Planned | Human oversight and source provenance required |

## Data and trust rules

- Every volleyball record carries a tenant identifier and is protected by forced row-level security.
- Team roster links only to athlete records in the same tenant.
- Match teams must belong to the same tenant as the match.
- Result submission is restricted to owner/admin/referee roles.
- Approval is restricted to owner/admin; submitted and approved transitions are audited.
- Approved results are locked in the current first release.
- No athlete phone, birth date, health or sensitive assessment data is exposed by the volleyball module.
- This module does not create a separate organization, identity, permission, audit, notification, backup or reporting system.
- Live database migration remains gated until the repository migration history and production ledger are reconciled.

## Release gates

1. Restore and reconcile all historical migration sources before applying migration 010.
2. Verify tenant-isolation and role-negative tests for every volleyball table and API.
3. Add transactional score-correction procedure and match roster snapshot workflow.
4. Run CI: typecheck, lint, tests, dependency audit and production build.
5. Deploy a protected preview; run smoke tests with synthetic data only.
6. Complete backup/restore evidence and privacy review before real athlete data is entered.

# METATYA SPORT OS — Implementation Roadmap

**Version:** 1.0  
**Status:** Execution plan; phases are gated by evidence.  
**Rule:** Build on the existing repository. Do not restart or replace working components without a documented reason.

## 1. Delivery strategy

Deliver the platform in controlled phases. Each phase has a defined scope, acceptance gate, and evidence record. A phase is not complete because its design document exists or because a deployment build succeeds.

### Phase 0 — Baseline and architecture alignment

**Goal:** Establish an accurate, reproducible picture of the current product.

Work:
- Inventory repository, branches, pull requests, CI, deployment configuration, and Supabase migrations.
- Map current application routes, API endpoints, database tables, RLS policies, and tenant resolution to the six-area capability map.
- Reconcile migration files with the actual Supabase migration history before any schema work.
- Identify existing code that can be retained, extended, or safely refactored.
- Record known gaps, assumptions, dependencies, and ownership boundaries.
- Preserve existing independent sport-module work; do not silently merge or discard it.

Acceptance:
- Repository and database inventory is recorded.
- Implemented versus planned capabilities are distinguished.
- Migration history and schema drift are understood.
- No live data or schema is changed during discovery.

### Phase 1 — Shared foundation and trust

**Goal:** Make the common platform safe and predictable before expanding business features.

Work:
- Finalize organization hierarchy and tenant membership model.
- Define permission catalogue and role-to-permission matrix with organization/team/event/record scope.
- Complete server-side authorization and RLS policy review.
- Add append-only audit coverage for sensitive and official operations.
- Define privacy classes, guardian consent, minor safeguarding, and restricted health/assessment access.
- Define data validation, status transitions, idempotency, and error conventions.
- Establish backup/restore design, retention, and isolated restore testing.
- Add integration/API contracts and secret handling standards.

Acceptance:
- Positive and negative authorization tests pass.
- At least two users across two tenants cannot cross-read or cross-write unauthorized data.
- Sensitive records and exports are access-controlled and audited.
- Restore test proves integrity and tenant boundaries in an isolated environment.
- Security and performance findings are triaged with evidence.

### Phase 2 — Core sports operations

**Goal:** Deliver dependable daily operations on top of the shared foundation.

Work:
- Organizations, branches, teams, groups, and seasons.
- Athlete/member, coach, staff, and official records.
- Membership invitations, approvals, and lifecycle.
- Training calendar, sessions, attendance, and facility allocation.
- Events, registration, eligibility, scheduling, and official assignments.
- Results, approvals, corrections, and history.
- Role-specific dashboards and responsive workflows.

Acceptance:
- End-to-end workflows pass with multiple organizations and roles.
- No tenant boundary regressions.
- API and UI validation are consistent.
- Official result changes have actor, timestamp, reason, and history.

### Phase 3 — Sport module framework and pilot

**Goal:** Prove that a sport can be added without changing shared-core meaning.

Work:
- Publish the sport-module contract and version compatibility rules.
- Establish sport/discipline catalogue and ruleset versioning.
- Implement one pilot module selected by product readiness.
- Add module-specific forms, scoring, eligibility, metrics, and reports through versioned interfaces.
- Keep module data namespaced and independently testable.

Acceptance:
- Pilot module tests pass independently and in platform integration.
- Shared athlete, organization, event, and result records retain stable meanings.
- Module upgrade, rollback, and data migration behavior are documented.
- No parallel shared admin, audit, permissions, backup, or reporting stack is introduced.

### Phase 4 — People development and intelligence

**Goal:** Add advanced athlete and organization development capabilities responsibly.

Work:
- Talent discovery, qualified assessment, referrals, and development plans.
- Coach and staff qualification lifecycle.
- Education and learning workflows.
- Analytics and business intelligence with data provenance.
- AI-assisted analysis and recommendations with human oversight.
- Research, innovation, media, broadcasting, and historical archives.

Acceptance:
- Sensitive assessments have qualified, scoped access and audit.
- Minors' workflows enforce guardian/consent requirements.
- Analytics and AI respect source permissions and disclose provenance/limitations.
- High-impact decisions remain subject to authorized human review.

### Phase 5 — Economy, marketplace, and facilities

**Goal:** Enable sustainable sports operations and commerce.

Work:
- Fees, subscriptions, invoices, payments, receipts, refunds, and reconciliation.
- Sponsorship, contracts, insurance administration, and procurement.
- Facilities, equipment, inventory, maintenance, and booking.
- Vendor directory, sports goods/services marketplace, and quote requests.
- Payment, tax, consumer, and regional compliance integrations as applicable.

Acceptance:
- Financial operations are auditable and reconciled.
- Payment secrets are server-side and never exposed in public bundles.
- Marketplace parties, orders, refunds, and disputes have explicit states and permissions.
- Legal and regional dependencies are documented before launch.

### Phase 6 — Release readiness and controlled rollout

**Goal:** Release only capabilities that have passed technical, security, operational, and user acceptance.

Work:
- Dependency and supply-chain review.
- Performance, accessibility, and responsive-device checks.
- Backup and restore drills.
- Incident response and operational runbooks.
- Monitoring, alerting, and support access review.
- Staging smoke tests and user acceptance.
- Progressive rollout by tenant and enabled sport module.

Acceptance:
- CI passes typecheck, lint, tests, and production build.
- Security review has no unresolved critical/high issue for the release scope.
- Tenant isolation and negative access tests pass.
- Restore drill passes with documented evidence.
- Runtime smoke tests pass in the target environment.
- Rollback and incident procedures are usable.
- Production status is declared only for the scope actually deployed and verified.

## 2. Current repository baseline

Based on the repository snapshot reviewed on 2026-11-19:

| Area | Observed state |
|---|---|
| Next.js application and Supabase SSR | Implemented baseline exists |
| Authentication and logout | Implemented baseline exists |
| Tenant resolution and active membership check | Implemented baseline exists |
| Members, events, results APIs | Initial GET/POST baseline exists |
| Multi-tenant tables and RLS | Migration file exists; live migration history still requires reconciliation |
| Dashboard | Initial dashboard exists |
| Sport-specific module | Volleyball scoring demo exists on a separate draft PR; not yet merged or runtime-verified |
| Public introduction | Separate draft PR exists; not yet merged or runtime-verified |
| Finance, training, insurance, advanced analytics, specialized portals | Roadmap/backlog, not verified as implemented |
| Audit, complete CRUD permissions, tenant-isolation integration tests, restore drills | Production backlog items |
| Netlify/Supabase production readiness | Outstanding configuration and smoke-test gates remain |

This baseline is a repository observation, not a claim about current live database or runtime health.

## 3. Immediate execution order

1. Complete Phase 0 inventory and evidence record.
2. Resolve open PR scope and CI status without merging unrelated work automatically.
3. Close security gaps in the existing tenant model before adding sensitive data.
4. Define and test the final role/permission matrix.
5. Complete core operations workflows.
6. Publish the sport-module contract and select a pilot.
7. Expand to development, intelligence, economy, and marketplace capabilities in gated releases.

## 4. Change and release controls

- All implementation work starts in a feature branch and is reviewed through a pull request.
- Do not commit directly to `main`.
- Do not merge existing or new pull requests without explicit owner approval.
- Do not run Supabase migrations, seed data, or destructive SQL on a live project without explicit owner approval, migration-history review, and verified backup/recovery readiness.
- Do not change Netlify visitor access, production environment variables, domains, or public exposure without explicit approval.
- Do not enable real athlete/medical/minor data until privacy, consent, access, audit, and recovery gates pass.
- Do not claim a feature is operational without runtime evidence.

## 5. Evidence record template

For every completed work item, record:
- Capability and scope.
- Branch and commit.
- Files, migrations, and services changed.
- Tests and exact results.
- Security and tenant-isolation evidence.
- Deployment environment and deploy identifier, if applicable.
- Runtime smoke-test result.
- Known limitations and rollback procedure.
- Status: proposed, designed, implemented, verified, release-ready, or operational.

## 6. Definition of done

A capability is done only when its implementation matches the documented scope, tests pass, authorization and tenant isolation are verified, operational documentation exists, and the status is accurately recorded. Production readiness is a separate gate from implementation completion.

# METATYA EXPERT OS — Volleyball Module Full Plan

**Parent:** METATYA EXPERT OS  
**Delivery model:** One integrated module inside the parent platform; not a separate product or duplicated organization system.  
**Pilot scope:** Volleyball module, designed to work with any authorized federation, board, association, club or academy tenant. No assumption that the pilot is a national governing body.

## 1. Volleyball-specific capabilities

| Capability | Status in this branch | Notes |
|---|---|---|
| Volleyball team management | Implemented in branch | Team identity, category, age group, season, venue and status |
| Athlete roster | Implemented in branch | Reuses shared athlete directory; jersey, position and captain |
| Competition and league setup | Implemented in branch | League, cup, round-robin, friendly and tournament records |
| Competition team registration | Implemented in branch | Group/pool code and seed |
| Match scheduling | Implemented in branch | Home/away, date/time, venue, best-of-3 or best-of-5 |
| Match lineup snapshot | API/schema implemented in branch | Snapshot constrained to active team members |
| Referee / official assignment | API/schema implemented in branch | Active tenant referee membership required; scorer may be staff |
| Set score validation | Implemented and unit-tested in branch | Best-of-3 / best-of-5, win-by-two and deciding-set target |
| Score submission and correction | Implemented in branch | Atomic database workflow with before/after audit |
| Result approval / rejection | Implemented in branch | Owner/admin approval; approved result is locked |
| Competition standings | Implemented in branch | Derived only from approved match results and configurable points |
| Automated round-robin fixture generation | Planned | Must respect competition format, venue/time constraints and byes |
| Knockout brackets and playoff progression | Planned | Bracket seeding, ties, walkovers and appeals require explicit rules |
| Live point-by-point scoreboard | Planned | Separate event stream, reconnect/replay and referee controls |
| Substitutions, libero replacement, timeouts and sanctions | Planned | Match event model and official match sheet required |
| Match protests, appeals and result corrections after approval | Planned | Formal reason, evidence, approval chain and immutable history |
| Certificates, records and season archive | Planned | Uses shared document, verification and archive services |

## 2. Shared capabilities owned by METATYA EXPERT OS

These are not duplicated inside Volleyball. They are shared platform capabilities used by every sport:

- Federation / governing body, provincial board, association, club, academy, branch, team and facility hierarchy.
- Identity, secure login, organizations, tenant isolation, roles, permissions, invitations and delegated administration.
- Athlete profiles and history, coach/staff/referee profiles, qualifications, licenses and expiry tracking.
- Athlete personal portal, guardian/parent access and consent for minors.
- Training plans, sessions, attendance, coach feedback and development history.
- Athlete assessment, performance indicators, talent discovery, referral and development pathways.
- Facility and court directory, booking, availability, maintenance and safety inspections.
- Equipment inventory, assignment, inspection, repair, service history and replacement planning.
- Membership, fees, invoices, receipts, insurance status, contracts and financial reports.
- Digital athlete/staff cards, membership credentials, licenses, QR verification and renewal workflow.
- Notifications, documents, imports/exports, search, reporting, analytics, audit, monitoring and API integrations.
- Encrypted backups, point-in-time/selective recovery, restore drills and continuity evidence.

**Status rule:** A shared capability is not considered delivered merely because it appears in this plan. It needs its own implementation, permission tests, tenant-isolation tests and runtime evidence.

## 3. Privacy, security and data integrity

- Every volleyball record is tenant-scoped and uses forced row-level security.
- Cross-tenant team, member, competition, match and roster references are rejected.
- Referee assignment requires an active referee membership in the same tenant.
- Match lineup entries must belong to one of the match teams and to that team's active roster.
- Only authorized roles can create teams, manage rosters, schedule matches, submit scores or approve results.
- Score changes and result decisions are recorded in an append-only audit table.
- Athlete phone, date of birth, health and sensitive assessment data are not exposed by the Volleyball module.
- No live schema change is allowed until the production migration ledger and missing historical migration sources are reconciled.
- No real athlete or minor data should be entered before privacy, consent, role and recovery gates pass.

## 4. Current release gates

1. Reconcile historical Supabase migrations and verify the helper functions/policies referenced by migration 010.
2. Run CI to completion: TypeScript, ESLint, tenant authorization tests, volleyball scoring tests, dependency audit and production build.
3. Run isolated database tests for cross-tenant reads/writes, role-denied operations, roster membership and official assignment.
4. Apply migration 010 only after the migration chain and restore readiness are verified.
5. Connect the correct METATYA EXPERT OS repository to its intended protected Netlify project; the currently published Netlify project is tied to a different repository.
6. Deploy a protected preview and run end-to-end tests with synthetic data only.
7. Complete backup/restore evidence and user acceptance before any production release.

## 5. Evidence status

The code and migration in the current feature branch are implementation work, not proof of production operation. The live Supabase schema has not been changed by this branch. A successful build, when achieved, will not by itself prove database, tenant-security or operational readiness.

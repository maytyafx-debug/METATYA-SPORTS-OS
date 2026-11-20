# METATYA SPORT OS — Volleyball Federation Operations

**Parent product:** METATYA SPORT OS  
**Module:** Volleyball  
**Implementation branch:** `feat/volleyball-federation-complete-v1`  
**Status:** Implementation in branch; CI, isolated database replay, preview smoke tests and owner acceptance are still required. Nothing in this document asserts live database or production operation.

## Product boundary

The volleyball federation is a sport module inside the shared METATYA SPORT OS platform. It uses the shared tenant, identity, authorization, member directory, audit and data services. It must not create a second identity system or a separate permission/backup/reporting platform.

## Existing volleyball workflows retained

- Team and roster management.
- Competition and league setup and team registration.
- Match scheduling, officials and lineup snapshots.
- Best-of-3 / Best-of-5 score submission and correction.
- Result approval/rejection and standings derived from approved results.

## New shared federation operations foundation

| Area | Tables / API resource | Operational scope |
|---|---|---|
| Federation hierarchy | `sports_org_units` / `org-units` | Federation, provincial and county boards, associations, clubs, academies, branches and departments |
| Membership lifecycle | `sports_member_memberships` / `memberships` | Application, approval, renewal, suspension, expiry, membership number and fee status |
| Coaches and referees | `sports_staff_profiles` / `staff` | Role, license number, grade and status |
| Credentials | `sports_staff_credentials` / `credentials` | Credential type, issuer, issue/expiry date and verification state |
| Guardian consent | `sports_member_guardian_consents` / `guardian-consents` | Purpose-bound consent, evidence reference, validity and revocation |
| Training and camps | `sports_training_programs`, `sports_training_sessions` | Programs, courses, camps, schedule, coach and facility |
| Attendance | `sports_training_attendance` / `attendance` | Present, absent, late and excused attendance |
| Athlete assessment | `sports_member_assessments` / `assessments` | Initial, technical, physical, performance and talent assessment |
| Development pathway | `sports_member_development_plans` / `development-plans` | Goals, assigned coach, review date and progress notes |
| Facilities | `sports_facilities` / `facilities` | Halls, courts, capacity, address and maintenance status |
| Booking | `sports_facility_bookings` / `bookings` | Booking requests and approval state |
| Finance | `sports_fee_invoices`, `sports_fee_payments` | Invoices, dues, payment references and confirmation state |
| Insurance | `sports_member_insurance` / `insurance` | Provider, policy, coverage, validity and verification |
| Communications | `sports_announcements` / `announcements` | Audience-scoped notices and publication window |
| Configuration | `sports_tenant_settings` / `settings` | Tenant-scoped versioned settings |
| Audit | `sports_platform_audit_events` | Append-only metadata audit for operational record changes |

The new Persian RTL workbench is available at `/volleyball/operations`, linked from the volleyball dashboard. Its API is rooted at `/api/sports/operations/:resource` and supports tenant-scoped list, create and constrained update operations. Deletion is intentionally not exposed by this first release; membership, finance, credentials and audit records should be deactivated or superseded rather than erased.

## Security and data rules

- Every operational row has a tenant boundary; the migration enables and forces RLS on all new tables.
- Cross-tenant references use composite foreign keys containing `tenant_id`.
- API routes resolve the authenticated user and active tenant membership on every request. The caller cannot submit or override `tenant_id`.
- Resource names, selectable columns and writable fields are allowlisted. Unknown resources and unknown payload fields are rejected.
- Finance, insurance and guardian-consent resources are restricted to owner/admin roles at the API and database layers.
- Training and assessment workflows are restricted to owner/admin/staff/coach roles.
- Public and anonymous access is revoked for the new tables.
- Operational changes create metadata-only audit events. Audit events are append-only; direct authenticated insert/update/delete is denied.
- Payment card data, bank credentials, passwords, health records and secret keys are not stored by these workflows.
- Credential and insurance evidence fields are storage references only; a private upload, malware scanning and authorized download service must be connected before real documents are uploaded.
- Athlete assessment fields are private operational data and must not be exposed through public member-directory endpoints.

## Important release limitations

This branch is not yet a complete live federation deployment:

1. The new migration has not been applied to the connected Supabase project. The historical migration-source gap documented in the baseline audit remains a hard blocker for live migration.
2. The generic operations workbench uses record IDs for linked records. A polished linked-record picker, athlete self-service portal, coach/referee self-service portal and guardian portal remain follow-up UI work.
3. Minor age verification must be wired to the final protected date-of-birth source. Until then, real minor assessments, talent-pathway records, travel/media consent and real athlete data must remain disabled. Consent records are purpose-bound, but the current branch does not yet prove that every minor workflow is blocked when consent is absent.
4. Payment gateway settlement, accounting reconciliation, refunds and bank verification are not integrated. The payment table stores a status and external reference only.
5. Insurance-provider verification and automated renewal reminders are not integrated.
6. Facility booking conflict detection, equipment inventory/maintenance, automated round-robin and knockout scheduling, live point-by-point scoreboard, substitutions, match protests/appeals and official certificates remain follow-up modules.
7. Notification delivery adapters, file upload/malware scanning, report export jobs, backup orchestration and isolated restore drills remain shared-platform release gates.
8. No production deploy, production migration, live seed, real athlete/minor data import or Production setting change is included in this branch authorization.

## Verification required

The branch adds:
- Unit tests for resource allowlists and payload validation.
- A PostgreSQL replay assertion for required tables, FORCE RLS, grants and append-only audit controls.
- A CI step that executes those assertions after the historical chain and volleyball integration tests.

The branch still needs successful GitHub Actions results and a protected Netlify Deploy Preview smoke test. Only after those results should the PR be considered ready for owner review. Live migration and production release require separate explicit authorization.

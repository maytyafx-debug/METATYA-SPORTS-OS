# METATYA SPORTS OS — Cross-Sport Domain Requirements

**Version:** 1.0  
**Date:** 2026-11-19  
**Status:** Consolidated requirements reference; implementation must be tracked separately.

## Product boundary

METATYA SPORTS OS is a multi-organization, multi-sport platform. The shared core must not encode rules that belong to one sport. Volleyball is an initial sport module/use case, not a separate platform and not a reason to specialize the shared data model.

## Organization hierarchy

Support configurable relationships among:

1. Provincial/regional sports bodies and federations
2. Local associations and governing bodies
3. Clubs and academies
4. Teams and training groups
5. Facilities and venues
6. Events and competitions

The hierarchy and authority relationships must be configurable; do not assume every sport uses an identical governance structure.

## Role and responsibility model

Roles are scoped to an organization and, where needed, to a team, event, or record:

- Platform owner/operator: platform-level configuration and service governance.
- Organization administrator: organization profile, staff, membership, and organization-wide settings.
- Club manager: club operations, rosters, schedules, and approved administrative records.
- Coach/head coach: assigned teams, training plans, attendance, athlete development notes within granted scope.
- Assistant coach: explicitly delegated team duties.
- Athlete: own profile, schedule, registration, and permitted personal records.
- Parent/guardian: authorized view and consent actions for a linked minor, limited by policy and applicable law.
- Referee/official: assigned events, match records, and official decisions within event scope.
- Competition organizer: event setup, registrations, schedules, and operational coordination.
- Finance officer: permitted fees, invoices, receipts, and reconciliation; no unrestricted access to athlete assessments.
- Medical/health professional: only if the organization enables this role and the person is appropriately qualified; access to strictly necessary records only.
- Auditor/read-only reviewer: scoped read access and audit evidence.
- Platform support: time-limited, approved, logged support access; no implicit access to tenant private data.

All permissions must be explicit, least-privilege, server-enforced, and tenant-scoped. A role label alone must never bypass record-level authorization.

## Shared domain modules

### Identity and membership
Profiles, invitations, membership applications, approval, status, affiliations, guardian links, and role assignments.

### Teams and training
Teams, age/category groups, rosters, coaches, sessions, attendance, facilities, and training plans.

### Events and competitions
Calendar, event setup, eligibility, registration, capacity, scheduling, venues, officials, status transitions, and cancellation handling.

### Results and records
Sport-specific result payloads, review/approval, publication, rankings, certificates, and immutable change history.

### Finance and administration
Configurable fees, invoices, payments, receipts, refunds, sponsorships, and financial reports. These are planned domain areas and must not be represented as implemented until verified.

### Athlete development
Baseline assessments, qualified evaluations, development plans, progress history, and consent-controlled referrals/opportunities.

### Communication
Announcements, notifications, consent-aware contact preferences, delivery records, and tenant-configured channels.

### Analytics
Organization activity, participation, event operations, attendance, performance trends, and configurable reports. Analytics must respect the same access and privacy boundaries as source records.

## Volleyball module boundary

Volleyball-specific concepts belong in a module, not in shared core tables or generic business logic. Examples include:

- Volleyball team roster constraints and match lineup concepts
- Set-by-set match results
- Match officials and match sheet fields
- Volleyball-specific competition formats and tie-break rules
- Court/rotation/position data where operationally required

The module must declare its schema, validation rules, permissions, and version. It must not change the meaning of shared athlete, organization, membership, event, or result records.

## Data and API rules

- Every tenant-owned record must carry a trusted tenant/organization relationship.
- Tenant identity supplied by a browser is untrusted until server-side membership authorization succeeds.
- Database row-level security is an independent defense layer.
- Validate all inputs against versioned schemas.
- Use stable identifiers and explicit status transitions.
- Keep sport-specific payloads versioned and namespaced.
- Record who changed what and when for sensitive or official records.
- Prevent duplicate registrations and conflicting event assignments through database constraints where appropriate.
- Support export and correction workflows without allowing unauthorized bulk extraction.

## Safeguarding and privacy requirements

- Data minimization and purpose limitation.
- Guardian-aware consent and age-sensitive access controls for minors.
- Separate sensitive health/assessment information from ordinary roster data.
- No public exposure of personal contact details or private athlete records.
- Consent must be revocable where applicable and scoped to purpose, recipient, and duration.
- Log privileged access and sensitive exports.
- Define retention, deletion, and secure recovery policies.

## Reliability and operational requirements

- Automated tests for tenant isolation, authorization failures, and sport-module validation.
- Backup and restore procedures with integrity verification.
- CI checks for type safety, lint, tests, dependency/security review, and production build.
- Safe migrations: inspect existing schema, back up, review SQL, and obtain explicit owner approval before applying to a live database.
- No secrets, access tokens, private keys, or personal production data in Git.
- Maintain a verified implementation status; a requirement or backlog item is not an implemented feature.

## Current implementation boundary

The repository README describes a current baseline covering authentication, multi-tenant membership, members, events, results, API authorization, and initial dashboards. It explicitly marks finance, insurance, training, specialized portals, advanced analytics, and sport modules as roadmap items. This requirements document does not change that implementation status.

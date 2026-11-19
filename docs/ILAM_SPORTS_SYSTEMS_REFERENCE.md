# Ilam Sports Systems — Reference Notes

**Destination:** METATYA SPORTS OS  
**Status:** Imported reference material; not a statement of current production capability  
**Prepared:** 2026-11-19

## Purpose

Preserve reusable requirements and operational patterns found in prior Ilam sports-system materials, while keeping the shared Sports OS independent of any single sport or federation.

## Source inventory reviewed

The following Library materials were located and reviewed:

- `PROJECT_MASTER.md` — historical sports-administration project brief and annual-event planning notes.
- `تقویم_مسابقات_تیراندازی_۱۴۰۵.docx` — historical annual competition-calendar example.
- First-, second-, and third-place certificate templates for 1405, including modern variants.
- `metatya-sport-elite-upgraded.html` — sports performance service/landing-page material containing consent and privacy principles.
- Existing METATYA SPORTS OS repository README and production backlog.

The source material is not a verified statement of current Ilam provincial federation policy. Dates, schedules, organization names, and operational status must be confirmed with the relevant authorized organization before use.

## Reusable sports-administration requirements

### 1. Organization and club administration

- Support provincial and local sports organizations, federations, clubs, academies, and teams as separate tenants.
- Maintain organization profile, branches, facilities, contacts, authorized officers, and membership status.
- Support multiple clubs/teams under an organization where its governance permits.
- Keep each tenant's records isolated and enforce authorization on the server and database layers.

### 2. People and membership

- Maintain athlete, coach, manager, team official, referee/official, guardian, and administrative profiles as appropriate.
- Record membership lifecycle: application, review, approval, active, suspended, expired, and archived.
- Support age groups and competition categories as configurable dimensions, not hard-coded assumptions.
- For minors, apply guardian involvement, age-appropriate consent, and restricted access to personal information.
- Keep sensitive health, identity, and contact data minimized and accessible only to explicitly authorized roles.

### 3. Competition and event administration

Reusable event-planning fields identified from the historical calendar and event form:

- Event/competition identifier and title
- Sport and discipline/module
- Competition level and category
- Age group and other permitted eligibility categories
- Date, start time, venue, and host organization
- Organizer and responsible officials
- Registration opening/closing dates and capacity
- Ruleset/version and eligibility requirements
- Status: draft, published, registration open, closed, in progress, completed, cancelled
- Results approval and publication status

The historical example used a year-long calendar, recurring events, and event-specific registration details. Its exact dates and frequency are examples only and are not adopted as an official Ilam calendar.

### 4. Results, rankings, and awards

- Register participants and teams against an event.
- Record results using a sport-specific result schema supplied by the relevant sport module.
- Support review, correction, approval, and publication workflows.
- Maintain an auditable result history; never silently overwrite an approved result.
- Generate configurable certificates/awards for placements or achievements.
- Include event, sport, category, participant, placement, date, issuer, authorized signatures, and a verifiable certificate identifier/QR where appropriate.

The archived first/second/third-place templates are reusable as a generic certificate design pattern. Their wording and visual assets should be rebuilt as neutral, configurable templates.

### 5. Communication and notifications

- Provide event announcements, registration reminders, schedule changes, result publication notices, and membership notifications.
- Keep channels (web, email, messaging integrations) replaceable and tenant-configurable.
- Record delivery status without exposing private contact data to unauthorized users.
- Messaging credentials must remain in a secret manager and never be committed to source control.

### 6. Performance development and talent pathway

The wider Sports OS scope includes a structured athlete-development pathway:

- Initial profile and baseline assessment
- Evaluation by appropriately qualified and authorized personnel
- Development goals and training-plan records
- Periodic progress reviews
- Coach/club communication with appropriate permissions
- Recommendations for learning and development opportunities
- Consent-controlled sharing and guardian participation for minors

This is a product requirement, not evidence that these workflows are already implemented.

## Privacy, safeguarding, and governance

The reviewed sports-service material explicitly emphasizes informed consent and limits on sharing individual information. Carry these principles into the platform:

- Explain purpose, access, retention, and deletion/request channels before collecting personal data.
- Share athlete information with coaches, clubs, federations, or other parties only under a valid, scoped authorization.
- Apply guardian-aware consent and safeguarding controls for minors.
- Do not expose medical or sensitive assessment records in general club dashboards.
- Keep an access and change audit trail for sensitive operations.
- Apply data minimization, retention schedules, and secure recovery.

## Source items intentionally not imported as product requirements

Some archived materials concern a single sport's specialized equipment, technical scoring, venue-specific safety procedures, and discipline-specific rules. Those details are deliberately excluded from the shared Sports OS core. If ever needed, they belong in a separately reviewed sport module and must be based on the relevant official rulebook and authorized approval.

## Verification labels

- **Source-backed pattern:** calendar planning, event forms, participant categories, results/rankings, certificates, communication, consent/privacy.
- **Product-level requirement:** multi-tenant administration, athlete development, guardian controls, modular sport rules, auditability.
- **Not verified:** official Ilam-wide calendar, current federation policy, live data, current operational workflows, and deployment status of any external legacy system.

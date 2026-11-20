# METATYA SPORT OS — Platform Ownership & Global Governance Model

**Document:** Platform Owner Governance Standard  
**Version:** 1.0 (design specification)  
**Status:** Proposed for review; documentation only  
**Baseline:** `main` at `c8e7af012b0ca6d3059c8876b1d3741c7f14e54e`  
**Scope:** Identity, global ownership, cross-tenant oversight, authorization, auditability, operational governance

## 1. Purpose and binding decisions

METATYA SPORT OS has one global platform-governance layer above independently owned tenants.

The approved ownership model is:

- **Platform Owner / Founder:** Ayat Ghamari. The Platform Owner has global, full platform authority and visibility across every tenant, module, user, permission, record, report, integration, operational setting, and platform subsystem.
- **Tenant Owner:** the legally/organizationally authorized owner of one tenant, with full authority only inside that tenant, subject to platform-wide security and integrity controls.
- **Tenant Admin and other tenant roles:** receive only explicitly assigned permissions within their tenant and assigned operational scope.

The Platform Owner's authority is global and does not depend on being a member of each tenant. The existing tenant memberships of the founder must not be treated as the source of global authority. Conversely, a tenant membership must never imply Platform Owner status.

This document records a design decision. It does not authorize a production migration, role assignment, data change, deployment, or merge.

## 2. What global oversight means

Platform Owner capabilities cover all of the following domains:

1. **Organizations and tenancy:** discover, inspect, configure, suspend/reactivate, and administer all tenants and their lifecycle.
2. **Identity and access:** inspect users, memberships, invitations, roles, permission assignments, sessions, and access history; manage platform and tenant access.
3. **People and athlete records:** access all organization and athlete records, including protected/private fields and history, subject to lawful purpose and applicable consent/retention requirements.
4. **Sports operations:** all disciplines, teams, squads, coaches, officials, competitions, registrations, fixtures, results, assessments, and performance records.
5. **Finance and commercial operations:** tenant and platform finance, invoices, payments, contracts, subscriptions, billing, and reports.
6. **Facilities and assets:** facilities, equipment, schedules, inventory, maintenance, and resource allocation.
7. **Modules and product configuration:** enable/disable/configure all present and future sports modules and shared platform services.
8. **Security and privacy:** policies, RLS posture, security findings, incidents, access reviews, data-retention controls, and privacy workflows.
9. **Infrastructure and integrations:** API connections, webhooks, storage, notification channels, external integrations, keys metadata, service health, and operational settings.
10. **Backup and recovery:** inspect backup status, initiate authorized backup/restore workflows, select recovery points, and oversee recovery verification.
11. **Analytics and reporting:** cross-tenant and platform-wide dashboards, exports, operational metrics, quality indicators, and audit reports.
12. **Governance and compliance:** ownership changes, policy versions, approvals, exceptions, incidents, and evidence records.

Every new module must declare its data domains, permissions, tenant boundary, sensitivity classification, audit events, export rules, and recovery behavior before being considered production-ready. The Platform Owner's global authority must automatically cover the module through the common authorization contract; modules must not implement private, inconsistent owner checks.

## 3. Authority model

| Principal | Scope | Authority |
|---|---|---|
| Platform Owner | Entire platform | Global read and management authority across all domains |
| Tenant Owner | One tenant | Full tenant administration and ownership actions within that tenant |
| Tenant Admin | Assigned tenant | Only delegated tenant permissions |
| Staff | Assigned tenant/resources | Operational permissions only |
| Coach / Official | Assigned teams/events | Role- and assignment-scoped sports permissions |
| Member / Athlete | Own account and permitted records | Self-service and explicitly shared information |

### 3.1 Platform Owner precedence

The authorization decision must recognize a verified Platform Owner before tenant-membership evaluation. A verified Platform Owner can inspect and administer any tenant without a synthetic membership row in every tenant.

The owner check must be based on a protected, database-backed platform-owner registry linked to the immutable Supabase Auth user UUID. It must not rely on:

- user-editable `user_metadata` or `raw_user_meta_data`;
- an email-address string supplied by a client;
- a client-side role flag;
- a request header, query parameter, or body field;
- a tenant membership or a role name supplied by the caller.

JWT `app_metadata` may be used only as a carefully managed cache/claim if the authoritative registry remains the source of truth and revocation/refresh behavior is explicitly handled. The safer baseline is a database-backed check for sensitive operations.

### 3.2 No privilege inheritance downward

Platform Owner status does not make a tenant owner, admin, coach, or member inside each tenant. Tenant ownership remains a separate legal/business relationship and must be recorded independently.

A tenant owner cannot grant themselves global privileges, change the Platform Owner registry, or access another tenant.

## 4. Identity and bootstrap requirements

- Bind the Platform Owner record to the confirmed Auth user UUID, not an email alias or mutable display name.
- The founder's existing tenant-admin memberships remain tenant memberships only; they are not a substitute for the global owner record.
- Do not create fake tenant memberships to simulate global access.
- Do not allow self-service signup, profile editing, or tenant administration to create or modify platform-owner records.
- Bootstrap the initial Platform Owner only through a reviewed, controlled migration/provisioning procedure after independent backup verification and a second read-back check.
- Enforce uniqueness and an explicit owner cardinality policy. The initial policy is one primary Platform Owner; any future additional platform-level operators require a separately approved governance change and narrowly scoped delegated privileges.
- Owner account recovery must be documented, MFA-protected where supported, and tested without sharing credentials.

The actual Auth UUID must be verified against the live Auth account immediately before any future provisioning. Never hardcode a mutable email lookup as the permanent authorization key.

## 5. Authorization architecture

Use one shared authorization contract across Next.js server routes, server actions, database RPCs, and PostgreSQL RLS.

Recommended evaluation order:

1. Validate the authenticated session and current user identity.
2. Resolve the authoritative Platform Owner record.
3. If verified as Platform Owner, grant the global platform policy for the requested operation.
4. Otherwise resolve active tenant membership and delegated permissions.
5. Validate tenant/resource ownership and assignment scope.
6. Apply sensitivity, consent, retention, and workflow constraints.
7. Return allow/deny and emit the required audit event.

**Default is deny.** A frontend-hidden control is not an authorization boundary. Every server endpoint and database access path must independently enforce the same policy.

### 5.1 Supabase/Postgres implementation constraints

- Keep the platform-owner registry in a non-exposed schema (for example, `private`) unless a documented reason requires otherwise.
- Enable RLS on exposed tables and apply least-privilege grants.
- Do not use `user_metadata` claims for authorization.
- Prefer `SECURITY INVOKER` functions. If a narrowly scoped `SECURITY DEFINER` helper is unavoidable to read the protected registry without recursive RLS, it must live in a non-exposed schema, use a fixed safe `search_path`, avoid dynamic SQL, explicitly validate `auth.uid()`, and have execute privileges revoked from `PUBLIC` and `anon` and granted only to the required role.
- Never expose Supabase `service_role` or secret keys to browser code.
- Views must not accidentally bypass RLS; use security-invoker behavior where supported or keep protected views outside exposed schemas.
- For UPDATE policies, verify both `USING` and `WITH CHECK` behavior.
- Do not rely on `TO authenticated` alone; every tenant-scoped policy must constrain the tenant and resource.
- The global-owner exception must be explicit and centrally tested, not copied as ad hoc SQL into each table policy.

### 5.2 Full access versus evidence integrity

The Platform Owner can read and administer all platform data and operational domains. However, no application principal—including Platform Owner—may silently rewrite or erase the audit evidence that records its own actions.

Audit logs, ownership history, backup manifests, and security evidence should be append-only for application roles. Corrections should be represented by new, linked events. This preserves trustworthy oversight rather than reducing the owner's authority.

## 6. Tenant isolation and tenant ownership

For all non-Platform-Owner principals:

- every tenant-owned record must be constrained by tenant ID;
- tenant IDs supplied by clients must be validated against the authenticated user's active membership and permissions;
- resource lookups must include tenant scope to prevent IDOR/BOLA;
- cross-tenant joins, exports, search, storage paths, and background jobs must preserve tenant scope;
- a tenant owner has no authority over another tenant, even if they know its identifiers.

Platform Owner is the only approved global cross-tenant authority. All cross-tenant owner actions must be auditable.

## 7. Audit, accountability, and owner visibility

Record, at minimum:

- actor user UUID and effective principal type;
- action, target type, target ID, and tenant ID (nullable for platform-level actions);
- timestamp and request/correlation ID;
- reason or ticket/reference for sensitive access where appropriate;
- before/after change references for privileged mutations;
- outcome, including denied attempts;
- source context needed for security review, without logging secrets or unnecessary sensitive payloads.

The Platform Owner must be able to search and review all audit records. Audit records must be protected against application-level update/delete. Export must preserve integrity metadata and access logs.

Sensitive athlete/private-data access is allowed to the Platform Owner under the approved global authority, but must be visible in the audit trail. For minors, guardian-consent requirements, lawful processing, retention, and disclosure constraints remain applicable; global authority does not cancel those obligations.

## 8. Ownership transfer and emergency controls

- Tenant ownership transfer requires verification of the incoming organization's authorized representative, explicit confirmation, and an immutable ownership-history event.
- Platform ownership transfer is a platform-level governance event, not a tenant membership update. It requires a dedicated, reviewed procedure, identity verification, explicit confirmation, recovery readiness, and an immutable record.
- No tenant owner or tenant admin can initiate or approve a Platform Owner transfer.
- Emergency access/recovery must be documented, time-bounded where applicable, and audited.
- Revoking or disabling the Platform Owner account must not occur through ordinary tenant-admin workflows.

## 9. Required data model (logical, not a migration)

These are logical responsibilities. Reuse existing structures where they already satisfy the contract; do not create duplicate tables.

| Logical entity | Responsibility |
|---|---|
| Platform owner registry | Authoritative global owner identity and status |
| Tenants | Organization boundary and lifecycle |
| Tenant memberships | User-to-tenant relationship and tenant role |
| Roles and permissions | Delegated tenant capabilities |
| Platform policies | Global governance settings and policy versions |
| Ownership history | Append-only tenant/platform ownership events |
| Audit events | Append-only privileged and sensitive activity |
| Access reviews | Periodic review of privileged identities and grants |
| Backup/recovery manifests | Evidence of backup versions and recovery verification |

## 10. Required tests before release

1. Verified Platform Owner can read and manage resources across every tenant and module.
2. Platform Owner authority works without a membership row in the target tenant.
3. A tenant owner cannot read or mutate another tenant's data.
4. A tenant admin cannot promote themselves or another user to Platform Owner.
5. User-editable metadata, email changes, client flags, and forged tenant IDs cannot create global authority.
6. Owner revocation/disablement takes effect within the documented session/token freshness window.
7. All API routes, RPCs, views, storage objects, background jobs, exports, and search paths enforce the shared contract.
8. Private athlete fields are inaccessible to unauthorized tenant roles and accessible to Platform Owner only through audited paths.
9. Audit records cannot be updated or deleted by application roles, including Platform Owner.
10. Tenant ownership transfer and platform ownership transfer preserve history and prevent lockout.
11. Backup/restore preserves owner registry, tenant boundaries, memberships, permissions, and audit integrity.
12. Regression tests prove existing tenant roles and volleyball operations continue to work.

Tests must use synthetic data only; never place real minor-athlete data in test fixtures.

## 11. Safe implementation sequence

1. Reconcile current repository code and live schema; confirm actual migration ledger and grants.
2. Produce a minimal-diff mapping from existing tables/functions/policies to this logical model.
3. Resolve migration-history discrepancies and design the private owner registry and centralized authorization helper.
4. Implement in an isolated branch and local/isolated PostgreSQL test environment only.
5. Run static checks, migration replay, RLS tests, API authorization tests, and Supabase advisors.
6. Obtain an independently stored and verified full backup before any live migration.
7. Present the exact migration, affected objects, data movement, rollback/forward-recovery plan, and expected access impact for explicit approval.
8. Only after separate approval, apply to live Supabase, verify read-back, then handle production deployment separately.

## 12. Current evidence and known gaps

At the time of this specification, the reviewed live database showed:

- no `platform_owners` or `platform_roles` table;
- no active `owner` tenant memberships;
- active tenant memberships existed for `admin` and `member`;
- private member data had not yet been moved to a dedicated private table;
- authenticated column grants for phone and birth date remained present on the public member table;
- `sports_member_history` did not have FORCE RLS enabled.

The repository contains tenant-role and tenant-security foundations, but the global Platform Owner model is not yet implemented or proven end-to-end. These observations must be rechecked before implementation because the live schema can change.

---

**Decision:** Adopt this document as the target governance design for METATYA SPORT OS, subject to review.  
**Not done:** No schema change, data migration, role assignment, production deployment, or merge is performed by this document.

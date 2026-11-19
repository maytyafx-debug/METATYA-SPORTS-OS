# METATYA SPORT OS — Phase 0 Baseline Audit

**Audit date:** 2026-11-19  
**Scope:** Repository, current branch/PR state, connected Supabase schema and migration ledger, RLS policies, grants, and Supabase advisors.  
**Method:** Read-only inspection. No production rows, schemas, policies, secrets, project settings, or deployment access were changed.

## 1. Executive result

The repository contains a working application foundation, but it is not yet a verified production-ready multi-tenant sports platform.

The most important result is a **repository-to-database migration-source gap**: the connected live Supabase project has twelve recorded migrations, while the repository does not contain the source SQL for several already-applied sports migrations. A new migration must not be applied until that history is reconciled.

A second important result is that the live database contains sports records and non-sports METATYA tables in the same Supabase project. This is currently a shared-project boundary, not infrastructure-level database isolation. It must be treated as transitional until the owner confirms the intended final data boundary.

## 2. Repository baseline

| Area | Observed state |
|---|---|
| Framework | Next.js 15.5.29, React 19.1.2, TypeScript 5.9.2 |
| Backend/data access | Supabase JS 2.57.4 and Supabase SSR 0.7.0 |
| Authentication | Supabase SSR session handling and authenticated user checks exist |
| Tenant resolution | Active membership and tenant selector validation exist; the main-branch resolver does not verify that the tenant itself is active |
| Sports APIs | Members, events, results expose initial GET/POST endpoints |
| CRUD completeness | Update/delete API workflows are not implemented for those resources |
| Roles | Main-branch route checks and live RLS policies are not fully aligned |
| Sport catalogue | Current records use free-text `sport_type`; no verified central sport catalogue is present |
| Organization hierarchy | Tenant-level base exists; full configurable federation/association/club/branch/team hierarchy is not implemented |
| Audit | A `sports_member_history` table exists in the live DB, but it is not a complete platform audit system |
| Backup/restore | No verified isolated restore drill was found |
| Tests | The security PR adds a role-capability unit test; database RLS integration tests are not yet present |
| Lockfile | No package lockfile is present in the inspected repository tree |
| Public release | Existing Netlify deployment is SSO-protected; it is not evidence of a public production launch |

## 3. Connected Supabase observations

The connected active Supabase project contains the Sports OS tables and also non-sports tables such as leads, content/data-bank, orders, and finance-related records.

This proves that the current database project is shared at the project/instance level. It does not prove that all products are using the same logical data or that access is currently exposed. However, it does not satisfy a strict independent-project/database boundary either.

**Required decision:** confirm whether this is a temporary legacy/staging arrangement or the intended long-term Sports OS database. Do not create, move, merge, or delete projects/data until the owner approves a migration and recovery plan.

The live database is non-empty. This audit did not read or export individual athlete, tenant, or result records.

## 4. Migration ledger and source gap

The connected database reports these applied migration versions:

| Version | Recorded name | Repository source status |
|---|---|---|
| 20260930180707 | metatya_initial_schema | Not in this Sports OS repository |
| 20261003040647 | revoke_rls_auto_enable_execute | Not in this Sports OS repository |
| 20261004030939 | create_leads_table | Not in this Sports OS repository |
| 20261007033631 | create_data_bank | Not in this Sports OS repository |
| 20261027090025 | create_orders_fallback | Not in this Sports OS repository |
| 20261029043344 | create_private_paid_packs_bucket | Not in this Sports OS repository |
| 20261117090249 | sports_multitenancy_core | Candidate source is `006_sports_multitenancy.sql`, but the filename/version do not match Supabase timestamp convention |
| 20261117090346 | sports_foreign_key_indexes | Matching timestamped source file is present |
| 20261117120859 | 007_public_sports_rbac_hardening | Source SQL is missing |
| 20261117120934 | 008_public_sports_rbac_policy_cleanup | Source SQL is missing |
| 20261118232655 | 009_sports_member_history | Source SQL is missing |
| 20261119105357 | 009_sports_member_history_repair | Source SQL is missing |

The proposed tenant-security migration is therefore stored as the next timestamped migration, `20261119120000_sports_tenant_security_alignment.sql`. It is **not applied**.

### Migration gate

Before any migration is applied:
1. Recover the exact SQL sources for the missing applied migrations from the original development/backup source.
2. Reconcile local and remote migration lists.
3. Verify the candidate `006_sports_multitenancy.sql` is identical in intent to the applied `sports_multitenancy_core` migration.
4. Run the complete migration chain in an isolated Supabase-compatible environment.
5. Compare resulting schema, policies, functions, triggers, and grants with the live schema.
6. Perform backup and restore verification before any production schema change.

Do not mark the database migration chain reproducible until all six checks pass.

## 5. Live RLS and application authorization findings

RLS is enabled on the five core Sports OS tables. The five core tables also have FORCE RLS enabled. The member-history table has RLS enabled but FORCE RLS is currently off.

The live role policies do not fully match the API role allowlists:

| Operation | Application route currently permits | Live RLS currently permits |
|---|---|---|
| Create member | owner, admin, staff | owner, admin |
| Create event | owner, admin, staff, coach | owner, admin |
| Create result | owner, admin, staff, coach | owner, admin, referee |
| Read members/events/results | API route has no explicit role gate | Live policies restrict rows by role |

This mismatch can produce confusing empty results or rejected writes. The draft security branch centralizes role capabilities, checks active tenant status, and proposes aligned RLS policies. Its earlier CI run failed at TypeScript check because the merged commit did not yet contain the TypeScript-extension compiler option; the current branch now contains that option. A fresh CI run is required to verify the current head.

## 6. Sensitive athlete data finding

The live `sports_members` table contains `phone` and `birth_date` fields, in addition to ordinary roster fields. Row-level security filters rows, not individual columns. Expanding member-directory read access to coaches/staff without separating those fields could expose contact and date-of-birth information through direct Data API queries.

The proposed timestamped security migration therefore:
- Copies `phone` and `birth_date` into a separate `sports_member_private` table without deleting the source values.
- Restricts that private table to owner/admin roles.
- Revokes broad table-level authenticated privileges on the general member table and grants only non-sensitive directory columns.
- Preserves tenant RLS and immutable tenant identity.
- Tightens member-history grants and FORCE RLS.

This proposal is not yet runtime-verified. It requires isolated database tests for data-copy counts, grants, RLS, rollback, and API compatibility before application.

## 7. Member-history and grants

The live `sports_member_history` table:
- Has RLS enabled, but FORCE RLS is off.
- Has owner/admin-only SELECT and INSERT policies.
- Has broad table privileges granted to `anon`, although no anon policy currently permits row access.
- Has no matching trigger discovered in the inspected sports trigger inventory.
- Has two foreign keys without covering indexes according to the Performance Advisor.

The proposed migration revokes anon privileges, restricts authenticated mutations, forces RLS, keeps owner/admin access, and adds the two missing indexes. This still does not make it a complete audit log; official result changes, permission changes, exports, financial operations, and privileged support access need their own event coverage.

## 8. Supabase Advisor results

### Security
- Three legacy non-sports tables have RLS enabled but no policies: `data_bank`, `finance_ledger`, and `monetization_opportunities`.
- Leaked-password protection is disabled in Supabase Auth.

The legacy tables and global Auth setting are outside this Sports OS phase's approved scope. They were not changed. The Auth setting requires a separate owner decision.

### Performance
- Two uncovered foreign keys exist on `sports_member_history`: `changed_by` and `(member_id, tenant_id)`.
- Four unused indexes were reported. Unused-index findings are not deletion instructions; retain them until workload evidence proves they are unnecessary.

## 9. Open pull requests and CI

At audit time:
- PR #4 — six-area master architecture: CI passed; PR remains open.
- PR #5 — tenant security and role alignment: draft; earlier CI run failed at TypeScript check. The current branch has since been updated and needs a fresh CI run.
- PR #3 — public introduction: draft; an earlier CI run passed.
- PR #1 — volleyball domain foundation: draft; an earlier CI run passed.

No PR was merged by this audit.

## 10. Phase 0 exit criteria

| Gate | Status |
|---|---|
| Repository and route inventory | Completed |
| Live project identification and read-only schema inspection | Completed |
| Current migration ledger captured | Completed |
| Migration source reconciliation | Blocked — missing historical SQL sources |
| API/RLS role mismatch documented | Completed |
| Sensitive member fields identified | Completed |
| Private-field separation proposed | Designed in pending migration; not verified |
| Two-tenant/two-user RLS integration tests | Not yet implemented |
| Isolated migration-chain execution | Blocked pending source recovery |
| Backup/restore drill | Not yet performed |
| Public production readiness | Not approved |

## 11. Immediate next work

1. Restore missing historical migration source files and reconcile migration history.
2. Run fresh CI on the current security branch and fix all failures.
3. Validate the private athlete-data separation in an isolated database.
4. Add positive and negative RLS integration tests for two tenants and multiple roles.
5. Implement a full audit-event model and verified backup/restore drill.
6. Decide the long-term independent Supabase project boundary for Sports OS.
7. Only then continue with full CRUD and the shared sports operations foundation.

**Final status:** Phase 0 repository/database inspection is complete. Phase 0 migration reproducibility is blocked. No live schema, records, secrets, Auth settings, or deployment access were modified.

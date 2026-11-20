# METATYA Sports OS — Supabase Migration Source Audit

**Audit date:** 2026-11-21  
**Mode:** Read-only inspection of the connected Supabase migration ledger, repository SQL sources, schema metadata, grants, RLS policies, and Supabase advisors.

## Connected project and migration ledger

The active Sports OS application is connected to Supabase project `megbqtoihsuouiaxpifl` (region `eu-west-1`). Its live migration ledger contains 12 entries, ending at `20261119105357_009_sports_member_history_repair`.

All 12 SQL source files corresponding to the currently recorded ledger entries were found in `supabase/migrations`. This supersedes the 2026-11-19 note that described several historical sources as missing. The repository now contains the timestamped source files for the core sports schema, FK indexes, RBAC hardening and cleanup, and member-history creation/repair.

The live ledger currently records:

- `20260930180707` — `metatya_initial_schema`
- `20261003040647` — `revoke_rls_auto_enable_execute`
- `20261004030939` — `create_leads_table`
- `20261007033631` — `create_data_bank`
- `20261027090025` — `create_orders_fallback`
- `20261029043344` — `create_private_paid_packs_bucket`
- `20261117090249` — `sports_multitenancy_core`
- `20261117090346` — `sports_foreign_key_indexes`
- `20261117120859` — `007_public_sports_rbac_hardening`
- `20261117120934` — `008_public_sports_rbac_policy_cleanup`
- `20261118232655` — `009_sports_member_history`
- `20261119105357` — `009_sports_member_history_repair`

## Confirmed live schema and security gaps

The active project currently has these Sports OS row counts: 4 tenants, 4 memberships, 3 members, 3 events, 4 results, and 0 member-history rows.

- RLS is enabled and FORCE RLS is enabled on the five core tenant/operational tables.
- `public.sports_member_history` has RLS enabled but FORCE RLS is currently false.
- The performance advisor identifies two missing covering indexes on `sports_member_history`: `sports_member_history_changed_by_fkey` and `sports_member_history_member_tenant_fk`.
- `public.sports_members` still contains `phone` and `birth_date` columns. The `authenticated` role currently has SELECT, INSERT, and UPDATE column privileges on both fields. Row policies restrict the rows to active tenant owners/admins/referees, but the current grant model still lets referees access these private columns. This is a confirmed privacy gap, not anonymous access.
- The proposed private table `public.sports_member_private` does not yet exist in the active project.

## Pending repository migrations — not applied

The following source files are present in the repository but are not recorded in the active project's migration ledger:

1. `20261119120000_sports_tenant_security_alignment.sql`
   - Adds the private schema tenant-role helper and last-active-owner protection.
   - Creates `sports_member_private`, copies existing phone/birth-date values without deleting the source values, and changes member/private-data RLS and grants.
   - Separates private member fields from the general member directory.
2. `20261119150000_sports_member_history_hardening.sql`
   - Forces RLS on member history, tightens its access policy, and adds the two indexes identified by the performance advisor.
   - Depends on the helper introduced by the preceding migration.
3. `20261119180000_010_volleyball_operational_module.sql`
   - Adds the Volleyball operational module.
4. `20261119200000_016_member_history_audit_and_private_grant_revoke.sql`
   - Removes residual private-column grants, adds append-only history behavior, and records member/private-field changes.
   - Its header declares dependencies on the preceding security migrations and the Volleyball module migration.

These migrations have not been applied or runtime-tested in an isolated database. Do not apply them to the active project yet. First validate the complete ordered chain, role behavior, column grants, data-copy behavior, rollback/recovery, and compatibility with the currently deployed application. In particular, the currently deployed application still comes from the legacy repository's `sports-os/` directory; it must be reconciled with the canonical repository before applying migrations that change member-column privileges.

## Advisor findings

### Active project `megbqtoihsuouiaxpifl`

- Security warning: leaked-password protection is disabled.
- Informational findings: `data_bank`, `finance_ledger`, and `monetization_opportunities` have RLS enabled without policies. This is default-deny behavior; confirm intended ownership/access before changing anything.
- Performance information: two missing member-history FK indexes and several unused indexes. Do not remove unused indexes without workload evidence.

### Legacy project `pphizckfdlqeveigkkqp`

- Its legacy `members`, `admins`, and page-view tables, plus its Sports OS tables, currently report zero rows; the project has one Auth user.
- The advisor reports `record_pageview(text)` as an anonymous-callable SECURITY DEFINER function. This is the intended public page-counter write path in its legacy migration.
- The live definition of `get_view_stats(text)` explicitly checks `auth.uid()` and `public.is_admin()`; the advisor's generic callable-function warning is not by itself proof of an authorization bypass.
- The Auth leaked-password protection warning also appears on this project.

## Guardrails

- No live SQL, migration, grant, policy, Auth setting, or data changes were made during this audit.
- Do not merge the two Supabase projects or move production data as part of this remediation.
- Do not apply pending migrations until the deployed app/repository source is aligned and the ordered migration chain has been validated in isolation.

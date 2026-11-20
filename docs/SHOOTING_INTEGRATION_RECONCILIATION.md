# Shooting Site ↔ METATYA Sports OS Reconciliation

**Audit date:** 2026-11-21  
**Scope:** Shooting-sports portal and its connection to the central Sports OS core. Read-only live inspection; no production deployment or database mutation.

## Executive status

The shooting portal, the central Sports OS repository, the Netlify deployment, and the two Supabase projects are not yet a single aligned release path. The active Netlify deployment is built from the legacy `ilam-shooting` repository's `sports-os/` application directory. The canonical `METATYA-SPORTS-OS` repository contains a separate Next.js application at its repository root. Both use the public `sports_*` schema, but their API route naming and implementation have diverged.

## Repository and deployment map

| Component | Verified state |
|---|---|
| Legacy public portal | `maytyafx-debug/ilam-shooting`, default branch `main`; static HTML/CSS/JS portal |
| Legacy executable Sports OS app | `ilam-shooting/sports-os/`; deployed branch `feat/sports-os-integrated-management-v1` |
| Current published Netlify deploy | Site `mtx-sportsos-7q4m9v`; deploy `6afd72a372f85b3032ff01f4`; state `ready` |
| Published source commit | `d14108c39058863c840a857c55df10c966131ae5` in `maytyafx-debug/ilam-shooting` |
| Canonical central repository | `maytyafx-debug/METATYA-SPORTS-OS`, default branch `main`; Next.js app at repository root |
| Proposed code correction | Draft PR #14: `fix/live-rls-role-alignment`; not merged or deployed |

The published Netlify deploy is not built from the canonical `METATYA-SPORTS-OS` repository. The legacy `ilam-shooting` repository's default branch is also not the same as the deployed feature branch.

## Application divergence

The deployed legacy app uses routes under `/api/core-sports/*` and its own `sports-os/lib/core-sports` service/auth implementation. The canonical repository uses `/api/sports/*`, `lib/tenancy/*`, and a different role-capability contract.

Both implementations connect to the same family of `public.sports_*` tables, but they are not drop-in interchangeable. In particular, the legacy application still has a phone-field path, while the canonical application rejects phone/birth-date fields through the general member API. Do not apply private-column grant migrations until the deployed application has been reconciled with the canonical code and tested.

## Supabase project selection

### Active project: `megbqtoihsuouiaxpifl`

Evidence:
- Its project URL matches the Supabase URL configured for the current Netlify site.
- It contains 4 tenants, 4 memberships, 3 members, 3 events, and 4 results.
- It has 4 Auth users.
- Its live migration ledger contains the 12 core/legacy/Sports OS migrations listed in `SUPABASE_MIGRATION_SOURCE_AUDIT.md`.

### Legacy project: `pphizckfdlqeveigkkqp`

Evidence:
- Its legacy shooting tables and Sports OS tables currently report zero rows.
- It has one Auth user.
- Its migration ledger contains legacy shooting/analytics history and an older Sports OS schema sequence.

The active project determination is based on connection configuration and live data, not on project names.

## Current live authorization contract

Verified against live RLS policies in `megbqtoihsuouiaxpifl`:

- `owner` and `admin`: read and manage operational members, events, and results.
- `referee`: read members/events/results and insert results; no member/event management.
- `coach`, `staff`, and `member`: no operational data access in the currently applied policy set.
- Membership provisioning and administration are not exposed by the current application API.

The canonical repository previously advertised some coach/staff capabilities that the live RLS policies did not permit. Draft PR #14 aligns API guards, dashboard controls, and role tests with the current live contract. The role test file was run independently with Node 22.16.0: 3 tests passed. A full repository typecheck/build and GitHub Actions run have not yet been verified.

## Confirmed privacy and migration blockers

- `sports_members.phone` and `sports_members.birth_date` remain on the general member table.
- The authenticated database role has SELECT/INSERT/UPDATE column privileges for those fields. Current row-level policy limits the accessible records to owner/admin/referee, so referees can still access private contact/date-of-birth fields.
- `sports_member_history` has RLS enabled but FORCE RLS is false.
- Two member-history foreign-key indexes are missing.

The repository already contains pending migrations `20261119120000`, `20261119150000`, `20261119180000`, and `20261119200000`. They are not present in the live migration ledger. They must be tested in order in an isolated database and checked against the deployed app before any production application.

## Recommended reconciliation sequence

1. Keep the central repository as the intended long-term source of truth, but do not change Netlify's repository/base-directory configuration yet.
2. Complete review and validation of draft PR #14; run the full repository tests, typecheck, and build.
3. Reconcile the legacy deployed app with the canonical root application, including route names, environment-variable support, member-private-data handling, and tenant/RLS behavior.
4. Test the pending migrations in an isolated database, including preservation and access tests for existing member data and negative cross-tenant cases.
5. Obtain explicit approval for the exact production migration sequence and a verified backup/restore point.
6. Only after successful validation, schedule a single low-cost Netlify source alignment/deploy and verify the deployed commit and runtime.

## Changes made during this audit

- No live database objects, rows, grants, policies, Auth settings, or Netlify configuration were changed.
- No production deployment was started.
- A draft code PR was opened to correct the confirmed role/UI/API mismatch in the canonical repository.

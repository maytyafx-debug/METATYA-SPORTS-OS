# METATYA SPORT OS — Supabase Migration Source Audit

**Audit date:** 2026-11-19  
**Mode:** Read-only inspection of the connected Supabase migration ledger and repository migration directory.

## Finding

The live database migration history is ahead of and not fully represented by the repository's `supabase/migrations` directory. The current repository contains:
- `006_sports_multitenancy.sql` (non-timestamped filename)
- `20261117090346_sports_foreign_key_indexes.sql`
- A proposed timestamped follow-on migration: `20261119120000_sports_tenant_security_alignment.sql`

The live database has already recorded versions:
- `20261117090249_sports_multitenancy_core`
- `20261117120859_007_public_sports_rbac_hardening`
- `20261117120934_008_public_sports_rbac_policy_cleanup`
- `20261118232655_009_sports_member_history`
- `20261119105357_009_sports_member_history_repair`

The SQL source for these applied migrations is not present in the inspected repository tree. The file `006_sports_multitenancy.sql` is a plausible source for the core migration but its name/version mismatch means this must be verified, not assumed.

## Why this matters

Without the original source files, a clean environment cannot reliably reproduce the live schema. A new migration applied on top of an incomplete local chain could produce drift, duplicate objects, or policy differences. The proposed security migration must not be applied to the live database or any shared environment until the historical chain is restored and compared.

## Recovery procedure

1. Retrieve the exact historical SQL from the original developer workstation, backups, prior branches, or migration artifacts.
2. Restore the files with their exact timestamp versions and names.
3. Do not rewrite old migrations to match the current schema; preserve their historical contents.
4. Run local and remote migration-list comparison.
5. Rebuild the schema in an isolated Supabase-compatible database.
6. Compare tables, columns, constraints, indexes, policies, functions, triggers, grants, and RLS flags with the live project.
7. Record the comparison and recovery test before any production change.

## Current proposed migration

`20261119120000_sports_tenant_security_alignment.sql` is a new follow-on proposal after the latest observed live migration version `20261119105357`. It includes:
- Central tenant-role policy alignment and active-tenant validation.
- Immutable tenant identity and last-active-owner protection.
- FORCE RLS on core Sports OS tables.
- A separate private member-data table for phone and birth date, with a non-destructive data copy.
- Column-level grants for the general member directory.
- Tightened access to member-history data.
- Missing member-history foreign-key indexes.

The migration has not been applied or runtime-tested. Its schema and policy behavior must be tested in isolation, including a rollback/recovery plan, before approval.

## Non-goals

- Do not modify unrelated METATYA legacy tables.
- Do not change global Supabase Auth settings in this phase.
- Do not drop old member columns or delete any records.
- Do not merge projects, move production data, or create a new Supabase project without explicit approval.

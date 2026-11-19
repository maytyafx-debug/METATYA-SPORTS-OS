# Migration history reconciliation — METATYA SPORT OS

## Purpose
Restore the exact migration source history needed for isolated replay. This branch does not apply SQL to the connected/live Supabase project.

## Provenance
The 12 timestamped historical SQL files were recovered verbatim from `supabase_migrations.schema_migrations` on 2026-11-19. The proposed follow-on files are copied from the existing PR #5 and PR #6 branches. The new 016 migration is proposed hardening and must pass the isolated replay before production use.

## Findings
- The live ledger contains 12 applied versions, including Sports OS migrations 007, 008, 009 and the 009 repair.
- The old unversioned `006_sports_multitenancy.sql` does not match the live ledger's `20261117090249 sports_multitenancy_core`; it is archived and must not be treated as an applied migration.
- The old FK-index file is archived; the timestamped version is restored from the exact ledger statement.
- The live database was populated at inspection time. CI uses synthetic fixtures only.
- No live schema, rows, grants, policies, Auth settings, secrets or deployment settings were changed.

## Release gates
1. Replay every timestamped migration in order on ephemeral PostgreSQL.
2. Seed synthetic member contact data before PR #5 security migration and verify private-data copy.
3. Verify column-level revocation, tenant isolation, role denials, append-only member history and volleyball RPC authorization.
4. Verify CI, application build and protected-preview smoke tests.
5. Obtain explicit approval before merging PRs, applying live migrations or deploying Production.

## Historical schema drift discovered by replay

The first clean replay stopped at the recorded 009 repair. The preceding recorded 009 migration creates `sports_member_history` without `tenant_id`; the later recorded repair uses `CREATE TABLE IF NOT EXISTS` and then indexes `tenant_id`, but does not add that column when the table already exists.

Read-only inspection of the live table on 2026-11-19 confirms `tenant_id uuid NOT NULL`, the tenant FK, and the composite `(member_id, tenant_id)` FK; the old single-column member FK is absent. The migration ledger does not contain the DDL that transformed the earlier table into that observed shape.

A separate candidate file `20261119000000_009_sports_member_history_repair.sql` exists on the historical `feat/volleyball-domain-foundation-v1` branch (commit `710099b0123afebbd089e60de411ae2e81df2b13`, 10:53:51 UTC). It is preserved in `docs/archive/` for provenance. It also uses `CREATE TABLE IF NOT EXISTS` and therefore does not itself add `tenant_id` to an already-existing earlier table.

For deterministic CI only, `tests/migration-replay-history-bridge.sql` models the missing, unrecorded schema precondition using the exact current live table shape. It is explicitly a test fixture, not a production migration and not evidence that the same SQL was executed historically. The original ledger migration files remain unchanged.

-- bootstrap-runtime-role.sql
--
-- Provisions the `tribely_app` runtime role and enforces the TRI-206
-- append-only posture on `moderation_action_audit`.
--
-- This file is executed by scripts/bootstrap-runtime-role.ts, which
-- substitutes ${runtime_password} and ${db_name} before sending to Postgres.
-- Do NOT run this file directly with psql — the placeholders are JS template
-- syntax, not psql :\`var\` syntax.
--
-- Idempotent: safe to re-run on any deploy.
--
-- DO NOT add ALTER TABLE ... OWNER TO tribely_app.
-- Postgres table owners bypass REVOKE TRUNCATE.
-- Owner must remain the migration / superuser role.

-- 1. Create runtime role if missing (LOGIN, password from env).
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'tribely_app') THEN
    EXECUTE format('CREATE ROLE tribely_app LOGIN PASSWORD %L', '${runtime_password}');
  END IF;
END $$;

-- 2. Baseline grants for normal app operation across all current tables.
GRANT CONNECT ON DATABASE "${db_name}" TO tribely_app;
GRANT USAGE ON SCHEMA public TO tribely_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO tribely_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO tribely_app;

-- 3. Default privileges so future migrations don't silently break runtime.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO tribely_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO tribely_app;

-- 4. TRI-206 lockdown: append-only enforcement on moderation_action_audit.
REVOKE UPDATE, DELETE, TRUNCATE ON moderation_action_audit FROM tribely_app;

-- TRI-165 severance exception: the report-retention sweep (TRI-198) MUST
-- NULL originatingReportId on audit rows when the originating moderation_reports
-- row is deleted >12 months later. The audit row itself persists as
-- legal-compliance evidence; only this single FK column may be cleared.
-- Repository SOT: severOriginatingReportId() in
-- apps/api/src/features/audit/infrastructure/persistence/moderation-action-audit.prisma-repository.ts
GRANT UPDATE ("originatingReportId") ON moderation_action_audit TO tribely_app;

-- 5. Verification block — fails the script if posture is wrong.
DO $$
BEGIN
  ASSERT (SELECT has_table_privilege('tribely_app', 'moderation_action_audit', 'INSERT')),
    'tribely_app must have INSERT on moderation_action_audit';
  ASSERT (SELECT has_table_privilege('tribely_app', 'moderation_action_audit', 'SELECT')),
    'tribely_app must have SELECT on moderation_action_audit';
  ASSERT NOT (SELECT has_table_privilege('tribely_app', 'moderation_action_audit', 'DELETE')),
    'tribely_app must NOT have DELETE on moderation_action_audit';
  -- Column-scoped UPDATE: originatingReportId is the ONLY column tribely_app may UPDATE
  -- (TRI-165 severance exception). All other columns must remain UPDATE-denied.
  ASSERT (SELECT has_column_privilege('tribely_app', 'moderation_action_audit', 'originatingReportId', 'UPDATE')),
    'tribely_app must have column-scoped UPDATE on originatingReportId (TRI-165 severance)';
  ASSERT NOT (SELECT has_column_privilege('tribely_app', 'moderation_action_audit', 'action', 'UPDATE')),
    'tribely_app must NOT have UPDATE on column action (append-only except originatingReportId)';
END $$;

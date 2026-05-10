-- Per-consumer offsets event bus + audit subsystem (TRI-38).
--
-- 1. outbox_events becomes append-only: drop per-event processing state
--    (processedAt/attempts/lastError) — those move to per-consumer state.
--    Add monotonic `seq`, plus `requestId` / `actorUserId` for audit
--    correlation that survives the publish→dispatch boundary.
-- 2. consumer_offsets: per-consumer cursor table (Kafka __consumer_offsets
--    equivalent). Independent progress, head-of-line block on failure,
--    bounded retry via `attempts` + `blockedAt`.
-- 3. http_audit_logs / event_audit_logs: separate tables (different
--    schemas, different retention later) — both keyed by `requestId`
--    for cross-table joins when investigating a single request.
-- 4. Backfill consumer_offsets for the 8 currently-known consumers so the
--    new dispatcher does NOT re-deliver the historical 21 outbox rows
--    (which were already processed under the old `processedAt` model).

-- DropIndex
DROP INDEX IF EXISTS "outbox_events_processedAt_occurredAt_idx";

-- AlterTable: outbox_events → append-only event log
ALTER TABLE "outbox_events" DROP COLUMN IF EXISTS "processedAt";
ALTER TABLE "outbox_events" DROP COLUMN IF EXISTS "attempts";
ALTER TABLE "outbox_events" DROP COLUMN IF EXISTS "lastError";

-- Add `seq` as a BIGSERIAL. Postgres auto-fills existing rows with
-- sequential values, preserving insertion order via the implicit OID/ctid
-- ordering. Future inserts get monotonic sequence numbers.
ALTER TABLE "outbox_events" ADD COLUMN "seq" BIGSERIAL;
ALTER TABLE "outbox_events" ADD CONSTRAINT "outbox_events_seq_key" UNIQUE ("seq");

-- Audit correlation columns. Nullable: events published from non-HTTP
-- contexts (boot seeding, future cron jobs) carry NULL until the caller
-- wraps in `runAsSystem(...)` / `runWithContext(...)`.
ALTER TABLE "outbox_events" ADD COLUMN "requestId" TEXT;
ALTER TABLE "outbox_events" ADD COLUMN "actorUserId" TEXT;

-- CreateIndex: dispatcher's hot path is `WHERE type = $1 AND seq > $2`.
CREATE INDEX "outbox_events_seq_idx" ON "outbox_events"("seq");
CREATE INDEX "outbox_events_type_seq_idx" ON "outbox_events"("type", "seq");

-- CreateTable: consumer_offsets (Kafka consumer-group offsets equivalent)
CREATE TABLE "consumer_offsets" (
    "consumerName" TEXT NOT NULL,
    "topic" TEXT NOT NULL,
    "committedSeq" BIGINT NOT NULL DEFAULT 0,
    "inFlightSeq" BIGINT,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lastError" TEXT,
    "lastErrorAt" TIMESTAMP(3),
    "blockedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "consumer_offsets_pkey" PRIMARY KEY ("consumerName")
);

CREATE INDEX "consumer_offsets_topic_idx" ON "consumer_offsets"("topic");
CREATE INDEX "consumer_offsets_blockedAt_idx" ON "consumer_offsets"("blockedAt");

-- CreateTable: http_audit_logs (per-request audit; no body content stored)
CREATE TABLE "http_audit_logs" (
    "id" TEXT NOT NULL,
    "requestId" TEXT NOT NULL,
    "method" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "status" INTEGER NOT NULL,
    "durationMs" INTEGER NOT NULL,
    "actorUserId" TEXT,
    "ip" TEXT,
    "userAgent" TEXT,
    "errorCode" TEXT,
    "receivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "http_audit_logs_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "http_audit_logs_requestId_key" ON "http_audit_logs"("requestId");
CREATE INDEX "http_audit_logs_actorUserId_receivedAt_idx" ON "http_audit_logs"("actorUserId", "receivedAt");
CREATE INDEX "http_audit_logs_receivedAt_idx" ON "http_audit_logs"("receivedAt");

-- CreateTable: event_audit_logs (event lifecycle audit)
CREATE TABLE "event_audit_logs" (
    "id" TEXT NOT NULL,
    "requestId" TEXT,
    "eventSeq" BIGINT NOT NULL,
    "eventType" TEXT NOT NULL,
    "consumerName" TEXT,
    "phase" TEXT NOT NULL,
    "attempt" INTEGER,
    "errorMessage" TEXT,
    "recordedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_audit_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "event_audit_logs_requestId_idx" ON "event_audit_logs"("requestId");
CREATE INDEX "event_audit_logs_eventSeq_consumerName_idx" ON "event_audit_logs"("eventSeq", "consumerName");
CREATE INDEX "event_audit_logs_consumerName_phase_recordedAt_idx" ON "event_audit_logs"("consumerName", "phase", "recordedAt");

-- Backfill consumer_offsets for the 8 currently-registered consumers.
-- committedSeq = MAX(seq) per topic from existing outbox_events. Effect:
-- the new dispatcher treats all historical events as already-handled (the
-- old buggy dispatcher already ran them under the processedAt model). New
-- events written post-deploy get picked up cleanly because their seq will
-- be greater than the seeded committedSeq.
--
-- COALESCE handles the empty-topic case (no events of that type yet → 0).
INSERT INTO "consumer_offsets" ("consumerName", "topic", "committedSeq", "updatedAt")
SELECT
    seed."consumerName",
    seed."topic",
    COALESCE((SELECT MAX("seq") FROM "outbox_events" WHERE "type" = seed."topic"), 0),
    CURRENT_TIMESTAMP
FROM (VALUES
    ('users.logUserRegistered',                     'users.userRegistered'),
    ('auth.issueEmailVerificationOnUserRegistered', 'users.userRegistered'),
    ('auth.logCredentialIssued',                    'auth.credentialIssued'),
    ('auth.logUserSignedIn',                        'auth.userSignedIn'),
    ('auth.logRefreshTokenIssued',                  'auth.refreshTokenIssued'),
    ('auth.logRefreshTokenRotated',                 'auth.refreshTokenRotated'),
    ('auth.logRefreshTokenRevoked',                 'auth.refreshTokenRevoked'),
    ('auth.logRefreshTokenReuseDetected',           'auth.refreshTokenReuseDetected')
) AS seed("consumerName", "topic")
ON CONFLICT ("consumerName") DO NOTHING;

-- Note: we deliberately leave the manual mapping above rather than auto-
-- discover from outbox_events.type. New consumers added later will have
-- their offset row inserted at boot (committedSeq=0 = process all
-- backfill, OR committedSeq=current MAX per the consumer's start_policy
-- — see ConsumerRegistry).

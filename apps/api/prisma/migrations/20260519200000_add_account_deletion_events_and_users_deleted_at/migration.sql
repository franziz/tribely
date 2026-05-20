-- TRI-134: account_deletion_events audit table + users.deletedAt tombstone column
-- Hand-authored: shadow DB not configured; no drift detected (only additive changes).
-- Verified against schema.prisma: no unrelated ALTER TABLE statements included.

-- AddColumn: users.deletedAt (nullable, tombstone timestamp)
ALTER TABLE "users" ADD COLUMN "deletedAt" TIMESTAMP(3);

-- CreateTable: account_deletion_events
-- userIdHash is a plain String (NOT a relation to users) — rows must outlive the
-- user record for PDPA s24 evidence integrity.
-- cascadeScope is TEXT[] (not JSONB) for simple query and operator readability.
-- outcome CHECK constraint enforces the closed enum.
CREATE TABLE "account_deletion_events" (
    "id" TEXT NOT NULL,
    "userIdHash" TEXT NOT NULL,
    "requestedAt" TIMESTAMP(3) NOT NULL,
    "completedAt" TIMESTAMP(3) NOT NULL,
    "requestId" TEXT,
    "cascadeScope" TEXT[] NOT NULL DEFAULT '{}',
    "outcome" TEXT NOT NULL,
    "failureReason" TEXT,
    "recordedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "account_deletion_events_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "account_deletion_events"
    ADD CONSTRAINT "account_deletion_events_outcome_check"
    CHECK (outcome IN ('completed', 'failed_rolled_back'));

-- CreateIndex
CREATE INDEX "account_deletion_events_userIdHash_recordedAt_idx" ON "account_deletion_events"("userIdHash", "recordedAt");

-- CreateIndex
CREATE INDEX "account_deletion_events_recordedAt_idx" ON "account_deletion_events"("recordedAt");

-- CreateIndex
CREATE INDEX "account_deletion_events_requestId_idx" ON "account_deletion_events"("requestId");

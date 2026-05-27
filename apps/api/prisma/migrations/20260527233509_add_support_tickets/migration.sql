-- TRI-213: Add support_tickets table for in-app support contact form.
--
-- Design decisions:
--   1. `userId` is a nullable plain String (NOT a FK to users) — pseudonymise-by-repo
--      pattern (TRI-29 / TRI-134 precedent): tickets survive account tombstone without
--      requiring a cascade delete on the support side.
--   2. `reportId` is free-text (NOT a FK to moderation_reports) — legal-compliance
--      guardrail: support persistence MUST NOT join to moderation_reports.
--   3. `category` and `status` are TEXT columns with DB CHECK constraints (per-codebase
--      convention: TEXT + CHECK, not Postgres enums).
--   4. `category` is VARCHAR(64) — bounded size, matches the 6-value closed enum.
--   5. Indexes: (userId, createdAt DESC) for rate-limit countRecentByUser query;
--      (status, createdAt) for triage queue; (category, createdAt) for analytics.
--
-- Additive only: no destructive changes, no existing tables modified.

-- CreateTable: support_tickets
CREATE TABLE "support_tickets" (
    "id"                TEXT NOT NULL,
    "userId"            TEXT,
    "userEmailSnapshot" TEXT,
    "category"          VARCHAR(64) NOT NULL,
    "message"           TEXT NOT NULL,
    "reportId"          TEXT,
    "status"            TEXT NOT NULL DEFAULT 'open',
    "createdAt"         TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt"        TIMESTAMP(3),

    CONSTRAINT "support_tickets_pkey" PRIMARY KEY ("id")
);

-- CHECK: category closed enum (6 values).
ALTER TABLE "support_tickets"
  ADD CONSTRAINT "support_tickets_category_check"
  CHECK ("category" IN (
    'report_followup_7d',
    'account_signin',
    'event_or_host',
    'app_broken',
    'feedback',
    'other'
  ));

-- CHECK: status closed enum (3 values).
ALTER TABLE "support_tickets"
  ADD CONSTRAINT "support_tickets_status_check"
  CHECK ("status" IN ('open', 'resolved', 'discarded'));

-- Indexes
CREATE INDEX "support_tickets_userId_createdAt_idx"
  ON "support_tickets"("userId", "createdAt" DESC);

CREATE INDEX "support_tickets_status_createdAt_idx"
  ON "support_tickets"("status", "createdAt");

CREATE INDEX "support_tickets_category_createdAt_idx"
  ON "support_tickets"("category", "createdAt");

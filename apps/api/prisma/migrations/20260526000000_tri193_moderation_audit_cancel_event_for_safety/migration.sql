-- TRI-193: Extend moderation_action_audit to support cancel_event_for_safety (Cat 4).
--
-- Changes:
--   1. DROP NOT NULL on reportId       — Cat 4 may have no upstream report row.
--   2. DROP NOT NULL on reporterUserId — no reporter when there is no upstream report.
--   3. ADD COLUMN reasonCode           — machine-readable safety code (e.g. 'safety').
--   4. ADD COLUMN justificationText    — operator free-text narrative (≤500 chars).
--   5. ADD COLUMN originatingReportId  — nullable link to a moderation_reports row.
--   6. DROP old action CHECK, recreate — add 'cancel_event_for_safety' to closed set.
--   7. ADD INDEX on originatingReportId — needed by TRI-141 sweep severance join.
--
-- Additive only: no destructive changes, no existing values affected.

-- 1. Make reportId nullable (Cat 4 cancellations may have no upstream report row).
ALTER TABLE "moderation_action_audit"
  ALTER COLUMN "reportId" DROP NOT NULL;

-- 2. Make reporterUserId nullable (no reporter when there is no upstream report).
ALTER TABLE "moderation_action_audit"
  ALTER COLUMN "reporterUserId" DROP NOT NULL;

-- 3. Add reasonCode column (machine-readable safety code).
ALTER TABLE "moderation_action_audit"
  ADD COLUMN "reasonCode" TEXT;

-- AddCheckConstraint: enforce closed enum for reasonCode column.
ALTER TABLE "moderation_action_audit"
  ADD CONSTRAINT "moderation_action_audit_reason_code_check"
  CHECK ("reasonCode" IN ('safety'));

-- 4. Add justificationText column (operator free-text narrative, ≤500 chars).
ALTER TABLE "moderation_action_audit"
  ADD COLUMN "justificationText" VARCHAR(500);

-- 5. Add originatingReportId column (nullable link to a moderation_reports row).
ALTER TABLE "moderation_action_audit"
  ADD COLUMN "originatingReportId" TEXT;

-- 6. Relax the action CHECK constraint to also permit 'cancel_event_for_safety'.
--    Drop the existing constraint and recreate with the additional value.
ALTER TABLE "moderation_action_audit"
  DROP CONSTRAINT "moderation_action_audit_action_check";

ALTER TABLE "moderation_action_audit"
  ADD CONSTRAINT "moderation_action_audit_action_check"
  CHECK ("action" IN ('touch', 'resolve_hidden', 'resolve_kept', 'cancel_event_for_safety'));

-- 7. Add index on originatingReportId for TRI-141 sweep severance join.
CREATE INDEX "moderation_action_audit_originatingReportId_idx"
  ON "moderation_action_audit"("originatingReportId");

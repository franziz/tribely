-- TRI-165: Add escalation columns to reports and moderation_action_audit.
--
-- Changes on `reports`:
--   1. ADD COLUMN escalatedAt          — nullable TIMESTAMP(3); null = not escalated.
--   2. ADD COLUMN escalationCategory   — nullable TEXT; closed enum CHECK.
--   3. ADD COLUMN externalRef          — nullable VARCHAR(500); operator-supplied ref.
--   4. ADD COLUMN escalatedByUserId    — nullable TEXT; operator user ID.
--   5. ADD CONSTRAINT paired-null: (escalatedAt IS NULL) = (escalationCategory IS NULL).
--   6. ADD CONSTRAINT paired-null: (escalatedAt IS NULL) = (externalRef IS NULL).
--   7. ADD CONSTRAINT paired-null: (escalatedAt IS NULL) = (escalatedByUserId IS NULL).
--   8. ADD CONSTRAINT CHECK on escalationCategory closed enum.
--   9. ADD INDEX on escalatedAt — drives list --state escalated filter.
--
-- Changes on `moderation_action_audit`:
--  10. DROP old action CHECK, recreate — add escalate | record_external_input |
--      resolve_with_override to the closed set (7 values total).
--  11. ADD COLUMN escalationCategory   — nullable TEXT; same 4-value CHECK as on reports.
--  12. ADD COLUMN externalRef          — nullable VARCHAR(500); populated when action='escalate'.
--  13. ADD COLUMN externalSource       — nullable TEXT; closed enum CHECK; populated when action='record_external_input'.
--  14. ADD COLUMN externalDisposition  — nullable VARCHAR(500); populated when action='record_external_input'.
--  15. ADD COLUMN externalReceivedAt   — nullable TIMESTAMP(3); operator-supplied; populated when action='record_external_input'.
--  16. ADD INDEX on (reportId, action)  — drives per-report external-input COUNT query.
--
-- Additive only: no destructive changes, no existing values affected.
-- No backfill: production has zero escalated reports; new columns ship NULL.

-- ============================================================
-- reports: new escalation columns
-- ============================================================

-- 1. escalatedAt — nullable; null = not escalated.
ALTER TABLE "reports"
  ADD COLUMN "escalatedAt" TIMESTAMP(3);

-- 2. escalationCategory — nullable TEXT with closed-enum CHECK.
ALTER TABLE "reports"
  ADD COLUMN "escalationCategory" TEXT;

-- 3. externalRef — nullable VARCHAR(500).
ALTER TABLE "reports"
  ADD COLUMN "externalRef" VARCHAR(500);

-- 4. escalatedByUserId — nullable TEXT.
ALTER TABLE "reports"
  ADD COLUMN "escalatedByUserId" TEXT;

-- 5. CHECK: escalationCategory closed enum.
ALTER TABLE "reports"
  ADD CONSTRAINT "reports_escalation_category_check"
  CHECK ("escalationCategory" IN (
    'criminal-content',
    'imminent-harm',
    'ambiguous-policy',
    'external-jurisdiction'
  ));

-- 6. Paired-null: escalatedAt ↔ escalationCategory must both be NULL or both non-NULL.
ALTER TABLE "reports"
  ADD CONSTRAINT "reports_escalated_at_category_paired_null_check"
  CHECK (("escalatedAt" IS NULL) = ("escalationCategory" IS NULL));

-- 7. Paired-null: escalatedAt ↔ externalRef.
ALTER TABLE "reports"
  ADD CONSTRAINT "reports_escalated_at_external_ref_paired_null_check"
  CHECK (("escalatedAt" IS NULL) = ("externalRef" IS NULL));

-- 8. Paired-null: escalatedAt ↔ escalatedByUserId.
ALTER TABLE "reports"
  ADD CONSTRAINT "reports_escalated_at_by_user_paired_null_check"
  CHECK (("escalatedAt" IS NULL) = ("escalatedByUserId" IS NULL));

-- 9. Index on escalatedAt — drives the list --state escalated filter.
CREATE INDEX "reports_escalatedAt_idx"
  ON "reports"("escalatedAt");

-- ============================================================
-- moderation_action_audit: widen action CHECK + new columns
-- ============================================================

-- 10. Widen action CHECK to include escalate | record_external_input | resolve_with_override.
--     Drop the existing constraint and recreate with the full 7-value set.
ALTER TABLE "moderation_action_audit"
  DROP CONSTRAINT "moderation_action_audit_action_check";

ALTER TABLE "moderation_action_audit"
  ADD CONSTRAINT "moderation_action_audit_action_check"
  CHECK ("action" IN (
    'touch',
    'resolve_hidden',
    'resolve_kept',
    'cancel_event_for_safety',
    'escalate',
    'record_external_input',
    'resolve_with_override'
  ));

-- 11. escalationCategory — same 4-value CHECK as on reports.
ALTER TABLE "moderation_action_audit"
  ADD COLUMN "escalationCategory" TEXT;

ALTER TABLE "moderation_action_audit"
  ADD CONSTRAINT "moderation_action_audit_escalation_category_check"
  CHECK ("escalationCategory" IN (
    'criminal-content',
    'imminent-harm',
    'ambiguous-policy',
    'external-jurisdiction'
  ));

-- 12. externalRef — nullable VARCHAR(500); populated when action='escalate'.
ALTER TABLE "moderation_action_audit"
  ADD COLUMN "externalRef" VARCHAR(500);

-- 13. externalSource — nullable TEXT with closed-enum CHECK; populated when action='record_external_input'.
ALTER TABLE "moderation_action_audit"
  ADD COLUMN "externalSource" TEXT;

ALTER TABLE "moderation_action_audit"
  ADD CONSTRAINT "moderation_action_audit_external_source_check"
  CHECK ("externalSource" IN ('counsel', 'partner', 'imda', 'other'));

-- 14. externalDisposition — nullable VARCHAR(500); populated when action='record_external_input'.
ALTER TABLE "moderation_action_audit"
  ADD COLUMN "externalDisposition" VARCHAR(500);

-- 15. externalReceivedAt — nullable TIMESTAMP(3); operator-supplied; populated when action='record_external_input'.
ALTER TABLE "moderation_action_audit"
  ADD COLUMN "externalReceivedAt" TIMESTAMP(3);

-- 16. Index on (reportId, action) — drives per-report external-input COUNT query.
CREATE INDEX "moderation_action_audit_reportId_action_idx"
  ON "moderation_action_audit"("reportId", "action");

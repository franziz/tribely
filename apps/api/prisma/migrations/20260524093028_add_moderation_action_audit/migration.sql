-- CreateTable
CREATE TABLE "moderation_action_audit" (
    "id" TEXT NOT NULL,
    "operatorUserId" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "reportId" TEXT NOT NULL,
    "targetType" TEXT NOT NULL,
    "targetId" TEXT NOT NULL,
    "reason" VARCHAR(500),
    "contentSnapshot" TEXT,
    "reporterUserId" TEXT NOT NULL,
    "actedAt" TIMESTAMP(3) NOT NULL,
    "requestId" TEXT,
    "recordedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "moderation_action_audit_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "moderation_action_audit_reportId_idx" ON "moderation_action_audit"("reportId");

-- CreateIndex
CREATE INDEX "moderation_action_audit_operatorUserId_actedAt_idx" ON "moderation_action_audit"("operatorUserId", "actedAt");

-- CreateIndex
CREATE INDEX "moderation_action_audit_actedAt_idx" ON "moderation_action_audit"("actedAt");

-- CreateIndex
CREATE INDEX "moderation_action_audit_requestId_idx" ON "moderation_action_audit"("requestId");

-- AddCheckConstraint: enforce closed enum for action column
ALTER TABLE "moderation_action_audit"
  ADD CONSTRAINT "moderation_action_audit_action_check"
  CHECK ("action" IN ('touch', 'resolve_hidden', 'resolve_kept'));

-- AddCheckConstraint: enforce closed enum for targetType column
ALTER TABLE "moderation_action_audit"
  ADD CONSTRAINT "moderation_action_audit_target_type_check"
  CHECK ("targetType" IN ('review', 'user', 'event'));

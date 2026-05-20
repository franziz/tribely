-- CreateTable
CREATE TABLE "reports" (
    "id" TEXT NOT NULL,
    "reporterUserId" TEXT NOT NULL,
    "targetType" TEXT NOT NULL,
    "targetId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "comment" VARCHAR(500),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "firstReviewedAt" TIMESTAMP(3),
    "resolvedAt" TIMESTAMP(3),
    "resolution" TEXT,
    "resolvedByUserId" TEXT,

    CONSTRAINT "reports_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "reports_resolvedAt_idx" ON "reports"("resolvedAt");

-- CreateIndex
CREATE INDEX "reports_targetType_targetId_idx" ON "reports"("targetType", "targetId");

-- CreateIndex
CREATE INDEX "reports_reporterUserId_idx" ON "reports"("reporterUserId");

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_reporterUserId_fkey" FOREIGN KEY ("reporterUserId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Domain invariants (string columns + CHECK constraints per codebase convention)
ALTER TABLE "reports" ADD CONSTRAINT "reports_targetType_check"
  CHECK ("targetType" IN ('review', 'user', 'event'));
ALTER TABLE "reports" ADD CONSTRAINT "reports_reason_check"
  CHECK ("reason" IN ('harassment', 'hate_speech', 'sexual_content', 'personal_information_disclosure', 'false_information', 'spam', 'other'));
ALTER TABLE "reports" ADD CONSTRAINT "reports_resolution_check"
  CHECK ("resolution" IS NULL OR "resolution" IN ('hidden', 'kept'));
ALTER TABLE "reports" ADD CONSTRAINT "reports_comment_length_check"
  CHECK ("comment" IS NULL OR char_length("comment") <= 500);
-- Append-only invariant: once resolvedAt is set, it cannot change.
-- (Enforced at the application layer in resolve-report.usecase.ts via ReportAlreadyResolved;
-- DB-level enforcement would require a trigger, deferred — domain layer is the source of truth here.)

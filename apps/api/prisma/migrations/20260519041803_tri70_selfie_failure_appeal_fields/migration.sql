-- AlterTable
ALTER TABLE "users" ADD COLUMN     "selfieAppealLockedAt" TIMESTAMP(3),
ADD COLUMN     "selfieAttemptCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "selfieLastFailureCategory" TEXT,
ADD COLUMN     "selfieStatus" TEXT;

-- AddCheckConstraint: selfieStatus values (TEXT + CHECK, not Postgres enum — per codebase convention)
ALTER TABLE "users"
  ADD CONSTRAINT "users_selfieStatus_check"
  CHECK ("selfieStatus" IN ('pending', 'approved', 'rejected'));

-- AddCheckConstraint: selfieLastFailureCategory values (TEXT + CHECK, not Postgres enum)
ALTER TABLE "users"
  ADD CONSTRAINT "users_selfieLastFailureCategory_check"
  CHECK (
    "selfieLastFailureCategory" IS NULL OR
    "selfieLastFailureCategory" IN ('poor_lighting', 'face_not_visible', 'quality_too_low', 'other')
  );

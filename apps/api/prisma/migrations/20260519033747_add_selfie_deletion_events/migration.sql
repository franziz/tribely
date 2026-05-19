-- CreateTable
CREATE TABLE "selfie_deletion_events" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "selfieId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "deletedAt" TIMESTAMP(3) NOT NULL,
    "requestId" TEXT,
    "recordedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "selfie_deletion_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "selfie_deletion_events_userId_deletedAt_idx" ON "selfie_deletion_events"("userId", "deletedAt");

-- CreateIndex
CREATE INDEX "selfie_deletion_events_deletedAt_idx" ON "selfie_deletion_events"("deletedAt");

-- CreateIndex
CREATE INDEX "selfie_deletion_events_requestId_idx" ON "selfie_deletion_events"("requestId");

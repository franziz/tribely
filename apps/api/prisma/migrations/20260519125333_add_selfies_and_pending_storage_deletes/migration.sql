-- TRI-79: selfies table and selfie_pending_storage_deletes queue
-- Generated via prisma migrate diff (schema-only, no shadow DB required)
-- No ALTER TABLE users — the `selfies Selfie[]` inverse relation is Prisma-only sugar.

-- CreateTable
CREATE TABLE "selfies" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "storageKey" TEXT,
    "approvedAt" TIMESTAMP(3),
    "rejectedAt" TIMESTAMP(3),
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "selfies_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "selfies_userId_status_idx" ON "selfies"("userId", "status");

-- CreateIndex
CREATE INDEX "selfies_status_approvedAt_idx" ON "selfies"("status", "approvedAt");

-- CreateIndex
CREATE INDEX "selfies_status_rejectedAt_idx" ON "selfies"("status", "rejectedAt");

-- AddForeignKey
ALTER TABLE "selfies" ADD CONSTRAINT "selfies_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "selfie_pending_storage_deletes" (
    "id" TEXT NOT NULL,
    "selfieId" TEXT NOT NULL,
    "storageKey" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "enqueuedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastAttemptAt" TIMESTAMP(3),
    "lastError" TEXT,

    CONSTRAINT "selfie_pending_storage_deletes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "selfie_pending_storage_deletes_attempts_enqueuedAt_idx" ON "selfie_pending_storage_deletes"("attempts", "enqueuedAt");

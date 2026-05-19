-- CreateTable
CREATE TABLE "post_event_check_ins" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "hostUserId" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "acknowledgedAt" TIMESTAMP(3),
    "flaggedAt" TIMESTAMP(3),
    "reportBody" TEXT,
    "resolvedAt" TIMESTAMP(3),

    CONSTRAINT "post_event_check_ins_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "post_event_check_ins_status_createdAt_idx" ON "post_event_check_ins"("status", "createdAt");

-- CreateIndex
CREATE INDEX "post_event_check_ins_hostUserId_status_idx" ON "post_event_check_ins"("hostUserId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "post_event_check_ins_userId_eventId_key" ON "post_event_check_ins"("userId", "eventId");

-- AddForeignKey
ALTER TABLE "post_event_check_ins" ADD CONSTRAINT "post_event_check_ins_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_event_check_ins" ADD CONSTRAINT "post_event_check_ins_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_event_check_ins" ADD CONSTRAINT "post_event_check_ins_hostUserId_fkey" FOREIGN KEY ("hostUserId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Enforce closed enum on status column. Prisma does not generate CHECK
-- constraints automatically — added manually per codebase convention
-- (cf. join_requests migration, events venue_category migration).
ALTER TABLE "post_event_check_ins"
  ADD CONSTRAINT "post_event_check_ins_status_check"
  CHECK (status IN ('pending', 'ok', 'flagged'));

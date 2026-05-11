-- CreateTable
CREATE TABLE "events" (
    "id" TEXT NOT NULL,
    "hostUserId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "venueAddress" TEXT NOT NULL,
    "venueLatitude" DECIMAL(9,6) NOT NULL,
    "venueLongitude" DECIMAL(9,6) NOT NULL,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "capacity" INTEGER NOT NULL,
    "category" TEXT NOT NULL,
    "costSplit" TEXT NOT NULL,
    "approvalMode" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "cancellationReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "events_hostUserId_idx" ON "events"("hostUserId");

-- CreateIndex
CREATE INDEX "events_status_startsAt_idx" ON "events"("status", "startsAt");

-- CreateIndex
CREATE INDEX "events_category_startsAt_idx" ON "events"("category", "startsAt");

-- AddForeignKey
ALTER TABLE "events" ADD CONSTRAINT "events_hostUserId_fkey" FOREIGN KEY ("hostUserId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

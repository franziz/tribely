-- CreateTable
CREATE TABLE "join_requests" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "requesterUserId" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decidedAt" TIMESTAMP(3),
    "decidedByUserId" TEXT,
    "decisionReason" TEXT,

    CONSTRAINT "join_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "join_requests_eventId_status_idx" ON "join_requests"("eventId", "status");

-- CreateIndex
CREATE INDEX "join_requests_requesterUserId_status_idx" ON "join_requests"("requesterUserId", "status");

-- AddForeignKey
ALTER TABLE "join_requests" ADD CONSTRAINT "join_requests_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "join_requests" ADD CONSTRAINT "join_requests_requesterUserId_fkey" FOREIGN KEY ("requesterUserId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Enforce one ACTIVE join request per (event, requester). Status terminals
-- (rejected, cancelled) are excluded so a user can re-request after either.
CREATE UNIQUE INDEX "join_requests_active_per_user_event_uniq"
  ON "join_requests" ("eventId", "requesterUserId")
  WHERE "status" IN ('pending', 'approved');

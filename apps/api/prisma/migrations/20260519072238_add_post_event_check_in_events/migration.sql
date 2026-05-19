-- CreateTable
CREATE TABLE "post_event_check_in_events" (
    "id" TEXT NOT NULL,
    "checkInId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "occurredAt" TIMESTAMP(3) NOT NULL,
    "requestId" TEXT,
    "recordedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_event_check_in_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "post_event_check_in_events_occurredAt_idx" ON "post_event_check_in_events"("occurredAt");

-- CreateIndex
CREATE INDEX "post_event_check_in_events_userId_reason_idx" ON "post_event_check_in_events"("userId", "reason");

-- AddCheckConstraint
ALTER TABLE "post_event_check_in_events" ADD CONSTRAINT "post_event_check_in_events_reason_check" CHECK (reason IN ('created', 'acknowledged', 'flagged', 'pseudonymised', 'deleted_by_retention'));

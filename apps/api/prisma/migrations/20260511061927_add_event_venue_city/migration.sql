-- Add `venueCity` as NOT NULL. A temporary DEFAULT '' lets the ALTER succeed if
-- the `events` table already contains rows (dev/staging may have hand-seeded
-- data before this migration). The default is dropped immediately after so the
-- column behaves like a normal required field at the app layer — Venue.create
-- enforces a non-empty city, so '' is a sentinel that can never originate from
-- the domain.
ALTER TABLE "events" ADD COLUMN "venueCity" TEXT NOT NULL DEFAULT '';
ALTER TABLE "events" ALTER COLUMN "venueCity" DROP DEFAULT;

CREATE INDEX "events_venueCity_startsAt_idx" ON "events"("venueCity", "startsAt");

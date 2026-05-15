-- =============================================================================
-- TRI-33: Add venueCategory column to events
--
-- DEFAULT 'other' backfill rationale:
--   Pre-migration rows (dev/staging local databases) will land in 'other', which
--   is the private-venue bucket. This is intentional per CEO Path A: no retroactive
--   enforcement — the CHECK only triggers on create/update touching venue fields.
--   Production has no data yet (Singapore launch is future), so no rows are
--   retroactively mis-classified. Manual cleanup may be needed on dev/staging
--   databases if test rows with known venue types were seeded before this migration.
-- =============================================================================

-- AlterTable
ALTER TABLE "events" ADD COLUMN     "venueCategory" TEXT NOT NULL DEFAULT 'other';

-- Enforce closed set of venue categories. Matches VenueCategory.VALUES in
-- apps/api/src/features/events/domain/value-objects/venue-category.ts.
ALTER TABLE "events" ADD CONSTRAINT "events_venueCategory_check"
  CHECK (
    "venueCategory" IN (
      'hawker_centre', 'park', 'museum', 'restaurant', 'bar', 'cafe',
      'beach', 'mrt_landmark', 'library', 'community_centre',
      'shopping_mall_common_area', 'tourist_attraction',
      'apartment', 'condo', 'home', 'hotel', 'hostel', 'other'
    )
  );

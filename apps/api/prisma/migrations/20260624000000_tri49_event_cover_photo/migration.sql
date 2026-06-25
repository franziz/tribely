-- TRI-49: Add coverPhotoStorageKey to events table.
-- Nullable TEXT column with no CHECK constraint and no DEFAULT — host supplies
-- the key at event-creation time after obtaining a presigned upload URL.
ALTER TABLE "events" ADD COLUMN "coverPhotoStorageKey" TEXT;

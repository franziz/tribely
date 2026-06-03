-- TRI-34: pre-event safety reminder
-- Adds a nullable TIMESTAMP(3) column to track when a user last acknowledged the
-- safety reminder modal. NULL means the user has never been shown (or not yet
-- confirmed) the reminder. No default, no index, no CHECK constraint per brief.
-- AlterTable
ALTER TABLE "users" ADD COLUMN "safety_reminder_seen_at" TIMESTAMP(3);

-- Align languages/interests with Prisma non-nullable String[] declaration.
-- Backfill any pre-existing NULL rows to '{}' then enforce NOT NULL DEFAULT '{}' at DB level.
-- Prevents mapper.map(...) crashes if a row is ever inserted outside the app layer.

UPDATE "users" SET "languages" = '{}'::TEXT[] WHERE "languages" IS NULL;
UPDATE "users" SET "interests" = '{}'::TEXT[] WHERE "interests" IS NULL;

ALTER TABLE "users"
  ALTER COLUMN "languages" SET DEFAULT '{}'::TEXT[],
  ALTER COLUMN "languages" SET NOT NULL,
  ALTER COLUMN "interests" SET DEFAULT '{}'::TEXT[],
  ALTER COLUMN "interests" SET NOT NULL;

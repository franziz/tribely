-- AlterTable
ALTER TABLE "users" ADD COLUMN     "avatarUrl" TEXT,
ADD COLUMN     "bio" TEXT,
ADD COLUMN     "currentCity" TEXT,
ADD COLUMN     "interests" TEXT[],
ADD COLUMN     "languages" TEXT[],
ADD COLUMN     "travelerType" TEXT;

-- CHECK constraint: travelerType TEXT + CHECK per TRI-41 convention
ALTER TABLE "users" ADD CONSTRAINT users_traveler_type_check
  CHECK ("travelerType" IS NULL OR "travelerType" IN ('local','traveling','expat'));

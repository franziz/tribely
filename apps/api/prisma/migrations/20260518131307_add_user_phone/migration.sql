-- AlterTable
ALTER TABLE "users" ADD COLUMN     "phone" TEXT,
ADD COLUMN     "phoneVerifiedAt" TIMESTAMP(3);

-- Partial unique index: only one verified holder per phone number.
-- Prisma DSL cannot express partial unique constraints — this index is the source of truth.
CREATE UNIQUE INDEX "users_phone_verified_unique" ON "users"("phone") WHERE "phoneVerifiedAt" IS NOT NULL;

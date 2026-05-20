-- CreateTable
CREATE TABLE "user_blocks" (
    "id" TEXT NOT NULL,
    "initiatorUserId" TEXT NOT NULL,
    "blockedUserId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_blocks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "user_blocks_initiatorUserId_idx" ON "user_blocks"("initiatorUserId");

-- CreateIndex
CREATE INDEX "user_blocks_blockedUserId_idx" ON "user_blocks"("blockedUserId");

-- CreateIndex
CREATE UNIQUE INDEX "user_blocks_initiatorUserId_blockedUserId_key" ON "user_blocks"("initiatorUserId", "blockedUserId");

-- Reject self-blocks at the DB layer (domain layer also enforces this; defense in depth)
ALTER TABLE "user_blocks" ADD CONSTRAINT "user_blocks_no_self_block_check" CHECK ("initiatorUserId" != "blockedUserId");

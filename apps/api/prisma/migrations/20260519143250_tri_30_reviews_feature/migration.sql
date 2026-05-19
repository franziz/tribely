-- CreateTable
CREATE TABLE "reviews" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "raterUserId" TEXT NOT NULL,
    "ratedUserId" TEXT NOT NULL,
    "rating" INTEGER NOT NULL,
    "comment" VARCHAR(500),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "hidden" BOOLEAN NOT NULL DEFAULT false,
    "hiddenAt" TIMESTAMP(3),
    "hiddenReason" TEXT,

    CONSTRAINT "reviews_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "reviews_ratedUserId_hidden_createdAt_idx" ON "reviews"("ratedUserId", "hidden", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "reviews_raterUserId_createdAt_idx" ON "reviews"("raterUserId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "reviews_eventId_idx" ON "reviews"("eventId");

-- CreateIndex
CREATE INDEX "reviews_hidden_hiddenAt_idx" ON "reviews"("hidden", "hiddenAt");

-- CreateIndex
CREATE UNIQUE INDEX "reviews_eventId_raterUserId_ratedUserId_key" ON "reviews"("eventId", "raterUserId", "ratedUserId");

-- AddForeignKey
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_raterUserId_fkey" FOREIGN KEY ("raterUserId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_ratedUserId_fkey" FOREIGN KEY ("ratedUserId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Domain invariants enforced at the DB layer
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_rating_check" CHECK ("rating" BETWEEN 1 AND 5);
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_comment_length_check" CHECK ("comment" IS NULL OR char_length("comment") <= 500);

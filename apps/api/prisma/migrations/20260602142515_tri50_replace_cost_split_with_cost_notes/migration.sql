/*
  Warnings:

  - You are about to drop the column `costSplit` on the `events` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "events" DROP COLUMN "costSplit",
ADD COLUMN     "costNotes" VARCHAR(200);

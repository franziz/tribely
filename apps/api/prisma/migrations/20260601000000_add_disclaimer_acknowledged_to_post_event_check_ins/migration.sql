-- TRI-238 Brief A3: Add disclaimer_acknowledged to post_event_check_ins.
--
-- Design decisions:
--   1. NOT NULL DEFAULT false — existing rows (pending check-ins created before
--      this migration) carry false, which is the correct semantic: no disclaimer
--      was acknowledged because flagging had not occurred yet.
--   2. Additive only: no destructive changes, no existing columns modified.

-- AlterTable: post_event_check_ins — add disclaimer_acknowledged column
ALTER TABLE "post_event_check_ins"
  ADD COLUMN "disclaimer_acknowledged" BOOLEAN NOT NULL DEFAULT false;

-- Extend the status closed enum on join_requests to include 'removed_by_host'.
-- No new column is needed: reason text reuses the existing decisionReason column.
--
-- The original join_requests migration did not add a CHECK constraint on status,
-- so the DROP below is a safe no-op. The ADD establishes the constraint for the
-- first time, covering the full five-value enum.

ALTER TABLE "join_requests" DROP CONSTRAINT IF EXISTS "join_requests_status_check";
ALTER TABLE "join_requests" ADD CONSTRAINT "join_requests_status_check"
  CHECK (status IN ('pending','approved','rejected','cancelled','removed_by_host'));

-- Partial indexes for audit queryability: host-initiated removals scoped to the
-- deciding host and to the affected requester respectively.

CREATE INDEX IF NOT EXISTS "join_requests_removed_by_host_host_idx"
  ON "join_requests" ("decidedByUserId", "decidedAt")
  WHERE "status" = 'removed_by_host';

CREATE INDEX IF NOT EXISTS "join_requests_removed_by_host_requester_idx"
  ON "join_requests" ("requesterUserId", "decidedAt")
  WHERE "status" = 'removed_by_host';

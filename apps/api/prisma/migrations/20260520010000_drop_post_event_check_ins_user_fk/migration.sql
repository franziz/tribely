-- TRI-134: drop post_event_check_ins.userId FK and post_event_check_ins.hostUserId FK
-- for pseudonymisation
--
-- FK resolution (a): drop the FK constraints so pseudonymised rows can carry a cuid2
-- pseudonym in userId / hostUserId with no corresponding User row.
--
-- Design rationale:
--   The TRI-134 account-deletion cascade rewrites userId to a freshly-generated cuid2
--   pseudonym (PseudonymiseCheckInsForUserUseCase, TRI-29) that has NO User row.
--   hostUserId can also reference a tombstoned user — same resolution applies.
--   Resolution (a) — drop FK — is preferred over (b) SET NULL (loses stable
--   pseudonym-as-identifier) and (c) create synthetic User row (adds row-creation
--   complexity to the cascade tx). Mirrors the pattern established for events.hostUserId
--   and join_requests.requesterUserId in migration tri134_drop_event_host_and_jr_requester_fks.
--
--   Check-ins remain fully queryable post-tombstone; the pseudonym serves as a stable,
--   opaque identifier across future queries. Referential integrity is the accepted cost;
--   all other FK constraints on this table (post_event_check_ins_eventId_fkey) remain intact.
--
-- Hand-authored: Neon compute suspended during migration generation; shadow DB not available.
-- Constraint names verified against migration 20260519071238_add_post_event_check_ins.
-- No unrelated ALTER TABLE statements.

-- Drop FK: post_event_check_ins.userId → users.id
ALTER TABLE "post_event_check_ins" DROP CONSTRAINT "post_event_check_ins_userId_fkey";

-- Drop FK: post_event_check_ins.hostUserId → users.id
ALTER TABLE "post_event_check_ins" DROP CONSTRAINT "post_event_check_ins_hostUserId_fkey";

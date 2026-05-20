-- TRI-134: drop events.hostUserId FK and join_requests.requesterUserId FK for pseudonymisation
--
-- FK resolution (a): drop the FK constraints so pseudonymised rows can carry a cuid2
-- pseudonym in hostUserId / requesterUserId with no corresponding User row.
--
-- Design rationale:
--   The TRI-134 account-deletion cascade rewrites hostUserId / requesterUserId to a
--   freshly-generated cuid2 pseudonym that has NO User row. Resolution (a) — drop FK —
--   is preferred over (b) SET NULL (loses stable pseudonym-as-identifier) and (c)
--   create synthetic User row (adds row-creation complexity to the cascade tx).
--
--   Events and join-requests remain fully queryable post-tombstone; the pseudonym serves
--   as a stable, opaque identifier across future queries. Referential integrity is the
--   accepted cost; all other FK constraints on these tables (e.g. events_eventId_fkey on
--   join_requests) remain intact.
--
-- Hand-authored: shadow DB not configured; drift is on post_event_check_ins (unrelated).
-- Verified against schema.prisma: no unrelated ALTER TABLE statements included.

-- Drop FK: events.hostUserId → users.id
ALTER TABLE "events" DROP CONSTRAINT "events_hostUserId_fkey";

-- Drop FK: join_requests.requesterUserId → users.id
ALTER TABLE "join_requests" DROP CONSTRAINT "join_requests_requesterUserId_fkey";

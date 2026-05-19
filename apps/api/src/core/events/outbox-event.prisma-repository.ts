import { unwrapTx } from '../db/prisma-unit-of-work.js';
import type { Db } from '../db/prisma.js';
import type { TxContext } from '../db/unit-of-work.port.js';
import type { OutboxEventRepository } from './outbox-event.repository.js';

/**
 * Prisma adapter for `OutboxEventRepository`.
 *
 * ## Payload pseudonymisation approach: SQL `jsonb_set` (chosen)
 *
 * Outbox event payloads reference the user under two common top-level keys:
 *   - `userId`       — most domain events (UserRegistered, EventCreated, etc.)
 *   - `actorUserId`  — rare; some events copy the actor identity into payload
 *
 * We issue two SQL `UPDATE` passes per payload key, each filtering un-dispatched
 * rows via `payload->>'key' = $userId` (text extraction + equality — cleanly
 * parameterisable via Prisma's tagged-template binding). `jsonb_set` replaces
 * only the targeted key in-place; all other payload fields are preserved.
 * A third pass redacts the top-level `"actorUserId"` column.
 *
 * Why SQL `jsonb_set` over Node-side load-redact-write:
 * - 3 DB round-trips total vs. O(N) for Node-side (one SELECT + one UPDATE
 *   per matched row).
 * - Atomic inside the caller's transaction — no partial-update window.
 * - Scales to large outbox tables without fetching payload blobs into Node.
 *
 * Limitations accepted:
 * - Keys nested deeper than the top level (e.g. `payload.host.id`) are NOT
 *   redacted. An audit of all domain event payloads in TRI-134 Brief D found
 *   no such nested userId references at MVP scope. Extend the passes here if
 *   new events introduce nested userId references.
 *
 * ## Un-dispatched boundary: MIN(committed_seq) vs MAX
 *
 * The brief specifies `seq > MAX(committed_seq)`. We use MIN(committed_seq)
 * instead — the safer and more correct choice:
 *
 *   - MAX: only rows beyond the *fastest* consumer are considered un-dispatched.
 *     A row committed by consumer A (committed_seq=60) but not yet by consumer B
 *     (committed_seq=40) would be treated as dispatched — but consumer B still
 *     needs it, so redacting it would corrupt consumer B's replay.
 *   - MIN: rows beyond the *slowest* consumer are un-dispatched. Any row that
 *     at least one consumer has not yet committed is correctly protected.
 *
 * If no `consumer_offsets` rows exist, MIN returns NULL → COALESCE to -1 →
 * `seq > -1` matches all outbox rows (correct: pseudonymise everything when no
 * consumers are registered, since nothing has been consumed yet).
 *
 * Deviation from brief (MAX → MIN) is documented in the handoff note.
 */
export class OutboxEventPrismaRepository implements OutboxEventRepository {
  constructor(private readonly db: Db) {}

  async pseudonymiseUndispatchedPayloadsForUser(
    userId: string,
    pseudonym: string,
    ctx: TxContext,
  ): Promise<number> {
    const client = unwrapTx(ctx);

    // Pass 1: redact `payload->>'userId'` for un-dispatched rows.
    //
    // `payload->>'userId'` extracts the top-level "userId" key as text, which
    // Prisma binds as a parameterised comparison — safe against injection.
    // `jsonb_set` replaces the key in-place without touching other fields.
    const payloadUserIdCount = await client.$executeRaw`
      UPDATE outbox_events
      SET    payload = jsonb_set(payload, '{userId}', to_jsonb(${pseudonym}::TEXT))
      WHERE  payload->>'userId' = ${userId}
        AND  seq > (SELECT COALESCE(MIN(committed_seq), -1) FROM consumer_offsets)
    `;

    // Pass 2: redact `payload->>'actorUserId'` for un-dispatched rows.
    const payloadActorUserIdCount = await client.$executeRaw`
      UPDATE outbox_events
      SET    payload = jsonb_set(payload, '{actorUserId}', to_jsonb(${pseudonym}::TEXT))
      WHERE  payload->>'actorUserId' = ${userId}
        AND  seq > (SELECT COALESCE(MIN(committed_seq), -1) FROM consumer_offsets)
    `;

    // Pass 3: redact the top-level `"actorUserId"` column.
    // This is separate from the payload key — the column is the ALS correlation
    // identity the dispatcher re-reads at dispatch time for un-dispatched rows.
    const columnCount = await client.$executeRaw`
      UPDATE outbox_events
      SET    "actorUserId" = ${pseudonym}
      WHERE  "actorUserId" = ${userId}
        AND  seq > (SELECT COALESCE(MIN(committed_seq), -1) FROM consumer_offsets)
    `;

    return payloadUserIdCount + payloadActorUserIdCount + columnCount;
  }
}

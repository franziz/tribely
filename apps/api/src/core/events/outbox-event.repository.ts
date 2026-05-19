import type { TxContext } from '../db/unit-of-work.port.js';

/**
 * Repository port for `outbox_events` mutations that are NOT part of the
 * normal publish path (which lives in `OutboxEventPublisher`).
 *
 * Currently the only consumer is the PDPA account-deletion cascade (TRI-134).
 * The interface is intentionally narrow — exposing a general-purpose
 * outbox-mutation API is out of scope and would undermine the append-only
 * contract for normal operations.
 */
export interface OutboxEventRepository {
  /**
   * Pseudonymise un-dispatched outbox rows whose payload JSON references
   * `userId` as a direct field value (key `userId` or `actorUserId`).
   *
   * "Un-dispatched" is defined as:
   *   `seq > (SELECT MAX(committed_seq) FROM consumer_offsets)`
   * i.e. at least one consumer has not yet processed the row. Already-
   * dispatched rows are left untouched — they were consumed before the
   * deletion and re-writing them would corrupt replay debugging.
   *
   * The caller (Brief E DeleteAccountUseCase) supplies
   * `pseudonym = sha256Hex(userId)` — the same hash stored in
   * `account_deletion_events.userIdHash` — so forensic cross-table joins
   * remain possible without retaining plaintext PII.
   *
   * Additionally, the direct column `actorUserId` on `outbox_events` is
   * updated by the same filter, since the dispatcher re-establishes the
   * ALS frame from that column.
   *
   * Returns the number of rows touched (actorUserId update + payload update
   * counts combined; a row counted twice if both the column and the payload
   * field were updated is an acceptable approximation — callers use the
   * count only for audit scope recording).
   */
  pseudonymiseUndispatchedPayloadsForUser(
    userId: string,
    pseudonym: string,
    ctx: TxContext,
  ): Promise<number>;
}

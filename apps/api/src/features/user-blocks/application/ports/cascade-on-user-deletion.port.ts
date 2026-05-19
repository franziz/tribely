import type { TxContext } from '@/core/db/unit-of-work.port.js';

/**
 * Port for cascading block cleanup when a user is deleted.
 *
 * TODO: Implemented by Brief 3A. When a user is hard-deleted all block rows
 * where they are the initiator OR the blocked user should be removed.
 */
export interface CascadeOnUserDeletionPort {
  execute(input: { userId: string }, ctx: TxContext): Promise<void>;
}

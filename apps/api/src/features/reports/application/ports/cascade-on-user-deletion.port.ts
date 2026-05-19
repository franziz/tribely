import type { TxContext } from '@/core/db/unit-of-work.port.js';

/**
 * Port for cascading user-deletion side-effects in the reports bounded
 * context (deleting reports filed by / about the deleted user, per
 * the PDPA retention policy).
 *
 * TODO: This is a stub interface. Brief 3A will implement the concrete
 * adapter. The container will bind a no-op stub in the interim.
 *
 * The two-arg signature (`input, ctx`) signals that this use case MUST be
 * invoked from inside an existing transaction — cascades must be atomic with
 * the parent user-deletion mutation (see CLAUDE.md evidence-integrity pattern).
 */
export interface CascadeOnUserDeletionPort {
  execute(input: { userId: string }, ctx: TxContext): Promise<void>;
}

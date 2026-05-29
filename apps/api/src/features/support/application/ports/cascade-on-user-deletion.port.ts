import type { TxContext } from '@/core/db/unit-of-work.port.js';

/**
 * Port for cascading user-deletion side-effects in the support bounded
 * context (pseudonymising support tickets submitted by the deleted user, per
 * the PDPA retention policy — scrub-not-retain; TRI-217 + legal sign-off).
 *
 * The two-arg signature (`input, ctx`) signals that this use case MUST be
 * invoked from inside an existing transaction — cascades must be atomic with
 * the parent user-deletion mutation (see CLAUDE.md evidence-integrity pattern).
 */
export interface CascadeOnUserDeletionPort {
  execute(input: { userId: string }, ctx: TxContext): Promise<void>;
}

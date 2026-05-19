import type { SelfieStatus } from '../../domain/entities/user.js';

export interface CanPerformVerifiedActionSignals {
  selfieStatus: SelfieStatus | null;
  selfieAppealLockedAt: Date | null;
}

/**
 * Pure projection — determines whether a user may perform actions that require
 * selfie verification right now.
 *
 * Semantics:
 *   - Returns `true` ONLY when selfieStatus === 'approved' AND selfieAppealLockedAt === null.
 *   - Returns `false` when selfieStatus is null, 'pending', or 'rejected'.
 *   - Returns `false` when selfieAppealLockedAt is non-null, regardless of status.
 *     (An appeal lock means the user has exhausted their attempts and is awaiting
 *     ops review — they cannot act even if status somehow reads 'approved'.)
 *
 * This is DISTINCT from `isVerified` (which signals the completion of the
 * verification journey). `canPerformVerifiedAction` is the real-time gate that
 * reflects whether the user's verified status is currently in good standing.
 *
 * Pure: no I/O. Safe to call in any context.
 */
export function computeCanPerformVerifiedAction(signals: CanPerformVerifiedActionSignals): boolean {
  if (signals.selfieAppealLockedAt !== null) return false;
  if (signals.selfieStatus !== 'approved') return false;
  return true;
}

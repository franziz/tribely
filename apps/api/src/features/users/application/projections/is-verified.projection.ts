export type VerificationSignalId = 'email' | 'phone' | 'selfie';

export interface VerificationSignals {
  emailVerifiedAt: Date | null;
  phoneVerifiedAt: Date | null;
  selfieApprovedAt: Date | null;
}

/**
 * Predicate map: one entry per known signal ID. The closed nature of this map
 * is the defensive guard — any signal ID not present here causes the function
 * to return `false`, even if the env-var enum theoretically prevents unknowns
 * from reaching the call site.
 */
const SIGNAL_PREDICATES: Record<VerificationSignalId, (s: VerificationSignals) => boolean> = {
  email: (s) => s.emailVerifiedAt !== null,
  phone: (s) => s.phoneVerifiedAt !== null,
  selfie: (s) => s.selfieApprovedAt !== null,
};

/**
 * Truth function for the `isVerified` projection.
 *
 * Returns `true` iff:
 *   - `signalSet` is non-empty
 *   - every signal ID in `signalSet` is a known signal
 *   - every known signal's predicate passes for the given `signals`
 *
 * Returns `false` in all other cases, including empty `signalSet` or any
 * unknown signal ID (defensive against future enum drift).
 *
 * Pure: no I/O, no env reads. The active signal set is passed in by the caller;
 * it is read from the environment at the composition root (DI container) and
 * injected via use cases.
 */
export function computeIsVerified(
  signals: VerificationSignals,
  signalSet: VerificationSignalId[],
): boolean {
  if (signalSet.length === 0) return false;

  for (const signalId of signalSet) {
    const predicate = (
      SIGNAL_PREDICATES as Record<string, ((s: VerificationSignals) => boolean) | undefined>
    )[signalId];
    if (predicate === undefined) return false;
    if (!predicate(signals)) return false;
  }

  return true;
}

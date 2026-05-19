/**
 * Result returned by PseudonymiseCheckInsForUserUseCase.
 *
 * A17 — non-trivial multi-field result extracted to its own DTO file.
 */
export interface PseudonymiseCheckInsForUserResult {
  /** Number of flagged rows where userId or hostUserId was replaced with a pseudonym. */
  pseudonymisedReports: number;
  /** Number of pending (and, in future, ok) rows belonging to the user that were hard-deleted. */
  deletedReports: number;
}

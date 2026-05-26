/**
 * Result returned by CancelEventForSafetyUseCase upon successful cancellation.
 * Fields: the created audit row identifier and the count of join-request holders notified.
 */
export interface CancelEventForSafetyResult {
  auditRowId: string;
  notifiedCount: number; // count of approved + pending join_requests at time of cancel
}

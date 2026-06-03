/**
 * Result shape for capability queries on the authenticated user.
 * The capability gate behind `canPostPrivateVenue` is the TRI-33
 * first-event-must-be-public enforcement; future fields extend
 * append-only without versioning.
 *
 * canPerformVerifiedAction (TRI-70): real-time gate — true only when
 * selfieStatus === 'approved' AND selfieAppealLockedAt === null.
 *
 * safetyReminderSeen (TRI-34): true iff users.safety_reminder_seen_at IS NOT
 * NULL — raw stored state, not a projection. Mobile reads this once per session
 * to decide whether to suppress the pre-event safety sheet.
 */
export interface UserCapabilitiesResult {
  canPostPrivateVenue: boolean;
  canPerformVerifiedAction: boolean;
  safetyReminderSeen: boolean;
}

import type { Consumer } from '@/core/events/consumer.port.js';
import {
  CHECK_IN_FLAGGED,
  type CheckInFlaggedEvent,
} from '@/features/check-ins/domain/events/check-in-flagged.event.js';

export interface ResetSafetyReminderOnCheckInFlaggedDeps {
  resetSafetyReminderSeen: { execute(input: { userId: string }): Promise<void> };
}

/**
 * When a check-in is flagged, clear the flagged user's safety-reminder seen
 * flag so the TRI-34 pre-event safety sheet re-shows on their next
 * request-to-join (TRI-270, AC-1/AC-2/AC-3/AC-4/AC-6/AC-8).
 *
 * AC-8: Net-new INDEPENDENT consumer of checkInFlagged; does not touch the
 * safety-report-email path. Per-consumer offsets (TRI-38) guarantee
 * independence — a failure here does not affect
 * `check-ins.sendSafetyReportEmailOnCheckInFlagged`.
 */
export const resetSafetyReminderOnCheckInFlagged = (
  deps: ResetSafetyReminderOnCheckInFlaggedDeps,
): Consumer<CheckInFlaggedEvent> => ({
  // This string is the PK in consumer_offsets — it MUST remain stable across
  // deploys. Renaming it without a migration replays all history.
  name: 'users.resetSafetyReminderOnCheckInFlagged',
  topic: CHECK_IN_FLAGGED,
  async handle(event) {
    await deps.resetSafetyReminderSeen.execute({ userId: event.payload.userId });
  },
});

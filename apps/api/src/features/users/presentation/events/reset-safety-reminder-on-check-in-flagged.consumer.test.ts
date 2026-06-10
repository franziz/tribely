import { describe, expect, it, vi } from 'vitest';
import type { ConsumerContext } from '@/core/events/consumer.port.js';
import {
  CHECK_IN_FLAGGED,
  checkInFlagged,
} from '@/features/check-ins/domain/events/check-in-flagged.event.js';
import { resetSafetyReminderOnCheckInFlagged } from './reset-safety-reminder-on-check-in-flagged.consumer.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const fakeConsumerCtx = (): ConsumerContext => ({
  requestId: 'req_test',
  actorUserId: null,
  attempt: 1,
});

const makePayload = (overrides?: Partial<Parameters<typeof checkInFlagged>[0]>) =>
  checkInFlagged({
    checkInId: 'checkin_abc123',
    userId: 'user_attendee01',
    eventId: 'event_xyz789',
    hostUserId: 'user_host99',
    flaggedAt: '2026-06-10T10:00:00.000Z',
    reportBody: 'I felt unsafe.',
    disclaimerAcknowledged: true,
    ...overrides,
  });

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('resetSafetyReminderOnCheckInFlagged', () => {
  it('subscribes to checkIns.checkInFlagged with the canonical consumer name', () => {
    const useCase = { execute: vi.fn().mockResolvedValue(undefined) };
    const consumer = resetSafetyReminderOnCheckInFlagged({ resetSafetyReminderSeen: useCase });

    expect(consumer.name).toBe('users.resetSafetyReminderOnCheckInFlagged');
    expect(consumer.topic).toBe(CHECK_IN_FLAGGED);
  });

  it('calls resetSafetyReminderSeen.execute with { userId } from the payload', async () => {
    const useCase = { execute: vi.fn().mockResolvedValue(undefined) };
    const consumer = resetSafetyReminderOnCheckInFlagged({ resetSafetyReminderSeen: useCase });

    await consumer.handle(makePayload({ userId: 'user_attendee01' }), fakeConsumerCtx());

    expect(useCase.execute).toHaveBeenCalledOnce();
    expect(useCase.execute).toHaveBeenCalledWith({ userId: 'user_attendee01' });
  });

  it('passes the userId from the event payload regardless of other payload fields', async () => {
    const useCase = { execute: vi.fn().mockResolvedValue(undefined) };
    const consumer = resetSafetyReminderOnCheckInFlagged({ resetSafetyReminderSeen: useCase });

    await consumer.handle(makePayload({ userId: 'user_different99' }), fakeConsumerCtx());

    expect(useCase.execute).toHaveBeenCalledWith({ userId: 'user_different99' });
  });
});

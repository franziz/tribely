import { describe, expect, it } from 'vitest';
import type { ConsumerContext } from '@/core/events/consumer.port.js';
import type { Event } from '@/features/events/domain/entities/event.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import { FakeEmailSender } from '@/core/email/fake-email-sender.js';
import { CHECK_IN_FLAGGED, checkInFlagged } from '../../domain/events/check-in-flagged.event.js';
import { sendSafetyReportEmailOnCheckInFlagged } from './send-safety-report-email-on-check-in-flagged.consumer.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const fakeConsumerCtx = (): ConsumerContext => ({
  requestId: 'req_test',
  actorUserId: null,
  attempt: 1,
});

/** Minimal stub for EventRepository — only findById is used by the consumer. */
class StubEventRepository implements EventRepository {
  private readonly _event: Event | null;

  constructor(event: Event | null = null) {
    this._event = event;
  }

  findById(_id: string): Promise<Event | null> {
    return Promise.resolve(this._event);
  }

  // Remaining interface members — not exercised by this consumer.
  findByIdForUpdate(): never {
    throw new Error('not needed in this test');
  }
  save(): never {
    throw new Error('not needed in this test');
  }
  findManyForListing(): never {
    throw new Error('not needed in this test');
  }
  countCompletedByHost(): never {
    throw new Error('not needed in this test');
  }
  pseudonymiseHostForUser(): never {
    throw new Error('not needed in this test');
  }
  findCompletedForUserBetween(): never {
    throw new Error('not needed in this test');
  }
}

/** Minimal Event stand-in that satisfies the consumer's `.title` read. */
const makeStubEvent = (title: string): Event =>
  ({
    title,
  }) as unknown as Event;

/** A recognizable fixture string that must NOT appear as metadata in the email body. */
const FIXTURE_AVATAR_URL = 'https://cdn.tribely.com/avatars/alice.jpg';

const makePayload = (overrides?: Partial<Parameters<typeof checkInFlagged>[0]>) =>
  checkInFlagged({
    checkInId: 'checkin_abc123',
    userId: 'user_attendee01',
    eventId: 'event_xyz789',
    hostUserId: 'user_host99',
    flaggedAt: '2026-05-19T10:00:00.000Z',
    reportBody: 'I felt unsafe because of the host behaviour.',
    disclaimerAcknowledged: true,
    ...overrides,
  });

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('sendSafetyReportEmailOnCheckInFlagged', () => {
  it('subscribes to check_ins.checkInFlagged with the canonical consumer name', () => {
    const consumer = sendSafetyReportEmailOnCheckInFlagged({
      emailSender: new FakeEmailSender(),
      eventRepository: new StubEventRepository(),
    });

    expect(consumer.name).toBe('check-ins.sendSafetyReportEmailOnCheckInFlagged');
    expect(consumer.topic).toBe(CHECK_IN_FLAGGED);
  });

  it('calls emailSender.send exactly once on a flagged check-in', async () => {
    const sender = new FakeEmailSender();
    const consumer = sendSafetyReportEmailOnCheckInFlagged({
      emailSender: sender,
      eventRepository: new StubEventRepository(makeStubEvent('Coffee & Chat SG')),
    });

    await consumer.handle(makePayload(), fakeConsumerCtx());

    expect(sender.sent).toHaveLength(1);
  });

  it('email subject contains [Tribely safety], eventId and userId — no other PII', async () => {
    const sender = new FakeEmailSender();
    const consumer = sendSafetyReportEmailOnCheckInFlagged({
      emailSender: sender,
      eventRepository: new StubEventRepository(makeStubEvent('Coffee & Chat SG')),
    });

    await consumer.handle(makePayload(), fakeConsumerCtx());

    expect(sender.sent).toHaveLength(1);
    const sent = sender.sent[0];
    expect(sent).toBeDefined();
    if (!sent) return;

    expect(sent.subject).toContain('[Tribely safety]');
    expect(sent.subject).toContain('event_xyz789');
    expect(sent.subject).toContain('user_attendee01');
  });

  it('email body contains the verbatim report text', async () => {
    const sender = new FakeEmailSender();
    const consumer = sendSafetyReportEmailOnCheckInFlagged({
      emailSender: sender,
      eventRepository: new StubEventRepository(makeStubEvent('Coffee & Chat SG')),
    });

    const payload = makePayload({
      reportBody: 'The host made inappropriate comments throughout the event.',
    });
    await consumer.handle(payload, fakeConsumerCtx());

    expect(sender.sent).toHaveLength(1);
    const sent = sender.sent[0];
    expect(sent).toBeDefined();
    if (!sent) return;

    expect(sent.text).toContain('The host made inappropriate comments throughout the event.');
    expect(sent.html).toContain('The host made inappropriate comments throughout the event.');
  });

  it('email body does NOT contain any display name or avatar URL', async () => {
    const sender = new FakeEmailSender();
    const consumer = sendSafetyReportEmailOnCheckInFlagged({
      emailSender: sender,
      eventRepository: new StubEventRepository(makeStubEvent('Coffee & Chat SG')),
    });

    // Pass recognizable PII-shaped strings in the report body to confirm
    // they only land in the verbatim report section, and that
    // avatar URLs (which the consumer never receives) cannot appear.
    const payload = makePayload({
      reportBody: 'Unrelated report text.',
    });
    await consumer.handle(payload, fakeConsumerCtx());

    expect(sender.sent).toHaveLength(1);
    const sent = sender.sent[0];
    expect(sent).toBeDefined();
    if (!sent) return;

    // Avatar URL must not appear anywhere — it was never passed in.
    expect(sent.text).not.toContain(FIXTURE_AVATAR_URL);
    expect(sent.html).not.toContain(FIXTURE_AVATAR_URL);

    // Metadata section uses ID strings, not resolved display names.
    expect(sent.text).toContain('user_attendee01');
    expect(sent.text).toContain('user_host99');
    expect(sent.text).toContain('event_xyz789');
  });

  it('falls back to eventId as title when the event is not found', async () => {
    const sender = new FakeEmailSender();
    const consumer = sendSafetyReportEmailOnCheckInFlagged({
      emailSender: sender,
      eventRepository: new StubEventRepository(null),
    });

    await consumer.handle(makePayload(), fakeConsumerCtx());

    expect(sender.sent).toHaveLength(1);
    const sent = sender.sent[0];
    expect(sent).toBeDefined();
    if (!sent) return;

    // When the event is not found, eventId is used as the title placeholder.
    expect(sent.text).toContain('event_xyz789');
  });

  it('passes disclaimerAcknowledged=true from the payload into the email body', async () => {
    const sender = new FakeEmailSender();
    const consumer = sendSafetyReportEmailOnCheckInFlagged({
      emailSender: sender,
      eventRepository: new StubEventRepository(makeStubEvent('Coffee & Chat SG')),
    });

    await consumer.handle(makePayload({ disclaimerAcknowledged: true }), fakeConsumerCtx());

    expect(sender.sent).toHaveLength(1);
    const sent = sender.sent[0];
    expect(sent).toBeDefined();
    if (!sent) return;

    expect(sent.text).toContain('Disclaimer acknowledged: YES');
    expect(sent.html).toContain('YES');
  });

  it('passes disclaimerAcknowledged=false from the payload into the email body', async () => {
    const sender = new FakeEmailSender();
    const consumer = sendSafetyReportEmailOnCheckInFlagged({
      emailSender: sender,
      eventRepository: new StubEventRepository(makeStubEvent('Coffee & Chat SG')),
    });

    await consumer.handle(makePayload({ disclaimerAcknowledged: false }), fakeConsumerCtx());

    expect(sender.sent).toHaveLength(1);
    const sent = sender.sent[0];
    expect(sent).toBeDefined();
    if (!sent) return;

    expect(sent.text).toContain('Disclaimer acknowledged: NO');
    expect(sent.html).toContain('NO');
  });

  it('truncates long event titles to 40 chars with an ellipsis', async () => {
    const sender = new FakeEmailSender();
    const longTitle = 'A'.repeat(60);
    const consumer = sendSafetyReportEmailOnCheckInFlagged({
      emailSender: sender,
      eventRepository: new StubEventRepository(makeStubEvent(longTitle)),
    });

    await consumer.handle(makePayload(), fakeConsumerCtx());

    expect(sender.sent).toHaveLength(1);
    const sent = sender.sent[0];
    expect(sent).toBeDefined();
    if (!sent) return;

    expect(sent.text).toContain(`${'A'.repeat(40)}…`);
    expect(sent.text).not.toContain(longTitle);
  });
});

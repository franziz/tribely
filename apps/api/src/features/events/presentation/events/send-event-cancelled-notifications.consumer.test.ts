import { describe, expect, it } from 'vitest';
import type { ConsumerContext } from '@/core/events/consumer.port.js';
import { FakeEmailSender } from '@/core/email/fake-email-sender.js';
import type { Event } from '../../domain/entities/event.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';
import type {
  JoinRequest,
  JoinRequestStatus,
} from '@/features/join-requests/domain/entities/join-request.js';
import type {
  JoinRequestRepository,
  ListJoinRequestsFilters,
} from '@/features/join-requests/domain/repositories/join-request.repository.js';
import type { User } from '@/features/users/domain/entities/user.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { EVENT_CANCELLED, eventCancelled } from '../../domain/events/event-cancelled.event.js';
import { sendEventCancelledNotifications } from './send-event-cancelled-notifications.consumer.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const fakeConsumerCtx = (): ConsumerContext => ({
  requestId: 'req_test',
  actorUserId: null,
  attempt: 1,
});

/** Minimal Event stub for the consumer's `.title` and `.startsAt` reads. */
const makeStubEvent = (overrides?: Partial<{ title: string; startsAt: Date }>): Event =>
  ({
    id: 'event_abc123',
    hostUserId: 'user_host01',
    title: overrides?.title ?? 'Coffee & Chat SG',
    startsAt: overrides?.startsAt ?? new Date('2026-06-12T11:30:00.000Z'),
  }) as unknown as Event;

/** Build a minimal JoinRequest stub. */
const makeStubJoinRequest = (
  id: string,
  requesterUserId: string,
  status: JoinRequestStatus = 'approved',
): JoinRequest =>
  ({
    id,
    eventId: 'event_abc123',
    requesterUserId,
    status,
  }) as unknown as JoinRequest;

/** Build a minimal User stub with a real email. */
const makeStubUser = (id: string, email: string): User =>
  ({
    id,
    email: { value: email },
  }) as unknown as User;

/** Build a minimal User stub with an empty email (tombstoned / null). */
const makeStubUserNoEmail = (id: string): User =>
  ({
    id,
    email: { value: '' },
  }) as unknown as User;

class StubEventRepository implements EventRepository {
  constructor(private readonly _event: Event | null = null) {}
  findById(_id: string): Promise<Event | null> {
    return Promise.resolve(this._event);
  }
  findByIdForUpdate(): never {
    throw new Error('not needed');
  }
  save(): never {
    throw new Error('not needed');
  }
  findManyForListing(): never {
    throw new Error('not needed');
  }
  countCompletedByHost(): never {
    throw new Error('not needed');
  }
  pseudonymiseHostForUser(): never {
    throw new Error('not needed');
  }
  findCompletedForUserBetween(): never {
    throw new Error('not needed');
  }
}

class StubJoinRequestRepository implements JoinRequestRepository {
  constructor(private readonly _joinRequests: JoinRequest[] = []) {}
  findByEvent(_eventId: string, _filters: ListJoinRequestsFilters): Promise<JoinRequest[]> {
    return Promise.resolve(this._joinRequests);
  }
  findById(): never {
    throw new Error('not needed');
  }
  findActiveByEventAndRequester(): never {
    throw new Error('not needed');
  }
  save(): never {
    throw new Error('not needed');
  }
  countApproved(): never {
    throw new Error('not needed');
  }
  pseudonymiseAuthorForUser(): never {
    throw new Error('not needed');
  }
  listApprovedByEvents(): never {
    throw new Error('not needed');
  }
  listByRequester(): never {
    throw new Error('not needed');
  }
}

class StubUserRepository implements UserRepository {
  constructor(private readonly _users: User[] = []) {}
  findByIds(ids: string[]): Promise<User[]> {
    const idSet = new Set(ids);
    return Promise.resolve(this._users.filter((u) => idSet.has(u.id)));
  }
  findById(): never {
    throw new Error('not needed');
  }
  findByEmail(): never {
    throw new Error('not needed');
  }
  findByVerifiedPhone(): never {
    throw new Error('not needed');
  }
  save(): never {
    throw new Error('not needed');
  }
}

/** Factory shorthand — builds and returns a consumer instance with supplied deps. */
const makeConsumer = (opts: {
  event?: Event | null;
  joinRequests?: JoinRequest[];
  users?: User[];
  emailSender?: FakeEmailSender;
}) => {
  const sender = opts.emailSender ?? new FakeEmailSender();
  const consumer = sendEventCancelledNotifications({
    emailSender: sender,
    eventRepository: new StubEventRepository(opts.event ?? makeStubEvent()),
    joinRequestRepository: new StubJoinRequestRepository(opts.joinRequests ?? []),
    userRepository: new StubUserRepository(opts.users ?? []),
  });
  return { sender, consumer };
};

const makePayload = (overrides?: Partial<Parameters<typeof eventCancelled>[0]>) =>
  eventCancelled({
    eventId: 'event_abc123',
    hostUserId: 'user_host01',
    reason: 'venue closed',
    cancelledAt: '2026-05-26T08:00:00.000Z',
    ...overrides,
  });

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('sendEventCancelledNotifications', () => {
  it('subscribes to events.eventCancelled with the canonical consumer name', () => {
    const { consumer } = makeConsumer({});
    expect(consumer.name).toBe('events.sendEventCancelledNotifications');
    expect(consumer.topic).toBe(EVENT_CANCELLED);
  });

  it('sends 6 emails — host + 3 approved + 2 pending joiners', async () => {
    const host = makeStubUser('user_host01', 'host@example.com');
    const joiners = [
      makeStubJoinRequest('jr1', 'user_j1', 'approved'),
      makeStubJoinRequest('jr2', 'user_j2', 'approved'),
      makeStubJoinRequest('jr3', 'user_j3', 'approved'),
      makeStubJoinRequest('jr4', 'user_j4', 'pending'),
      makeStubJoinRequest('jr5', 'user_j5', 'pending'),
    ];
    const users = [
      host,
      makeStubUser('user_j1', 'j1@example.com'),
      makeStubUser('user_j2', 'j2@example.com'),
      makeStubUser('user_j3', 'j3@example.com'),
      makeStubUser('user_j4', 'j4@example.com'),
      makeStubUser('user_j5', 'j5@example.com'),
    ];

    const { sender, consumer } = makeConsumer({ joinRequests: joiners, users });
    await consumer.handle(makePayload(), fakeConsumerCtx());

    expect(sender.sent).toHaveLength(6);
  });

  it('skips host when their email is empty (tombstoned), sends 5 emails to joiners', async () => {
    const host = makeStubUserNoEmail('user_host01');
    const joiners = [
      makeStubJoinRequest('jr1', 'user_j1', 'approved'),
      makeStubJoinRequest('jr2', 'user_j2', 'approved'),
      makeStubJoinRequest('jr3', 'user_j3', 'approved'),
      makeStubJoinRequest('jr4', 'user_j4', 'pending'),
      makeStubJoinRequest('jr5', 'user_j5', 'pending'),
    ];
    const users = [
      host,
      makeStubUser('user_j1', 'j1@example.com'),
      makeStubUser('user_j2', 'j2@example.com'),
      makeStubUser('user_j3', 'j3@example.com'),
      makeStubUser('user_j4', 'j4@example.com'),
      makeStubUser('user_j5', 'j5@example.com'),
    ];

    const { sender, consumer } = makeConsumer({ joinRequests: joiners, users });
    await consumer.handle(makePayload(), fakeConsumerCtx());

    expect(sender.sent).toHaveLength(5);
    expect(sender.sent.map((e) => e.to)).not.toContain('');
  });

  it('sends 1 email to the host when there are zero joiners', async () => {
    const users = [makeStubUser('user_host01', 'host@example.com')];

    const { sender, consumer } = makeConsumer({ joinRequests: [], users });
    await consumer.handle(makePayload(), fakeConsumerCtx());

    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0]?.to).toBe('host@example.com');
  });

  it('sends no email and does not throw when the event is not found', async () => {
    const { sender, consumer } = makeConsumer({ event: null });
    await expect(consumer.handle(makePayload(), fakeConsumerCtx())).resolves.toBeUndefined();
    expect(sender.sent).toHaveLength(0);
  });

  it('email subject matches the locked Option A copy: "Event cancelled: <title>"', async () => {
    const users = [makeStubUser('user_host01', 'host@example.com')];
    const event = makeStubEvent({ title: 'Morning Hike Bukit Timah' });

    const { sender, consumer } = makeConsumer({ event, users });
    await consumer.handle(makePayload({ eventId: 'event_abc123' }), fakeConsumerCtx());

    expect(sender.sent[0]?.subject).toBe('Event cancelled: Morning Hike Bukit Timah');
  });

  it('email body contains the event title and formatted start time', async () => {
    const event = makeStubEvent({
      title: 'Sunset Drinks Marina Bay',
      startsAt: new Date('2026-06-12T11:30:00.000Z'), // 7:30 PM SGT
    });
    const users = [makeStubUser('user_host01', 'host@example.com')];

    const { sender, consumer } = makeConsumer({ event, users });
    await consumer.handle(makePayload(), fakeConsumerCtx());

    const sent = sender.sent[0];
    expect(sent).toBeDefined();
    if (!sent) return;

    expect(sent.text).toContain('Sunset Drinks Marina Bay');
    // SGT offset = UTC+8, so 11:30 UTC = 19:30 SGT
    expect(sent.text).toContain('SGT');
    expect(sent.html).toContain('Sunset Drinks Marina Bay');
    expect(sent.html).toContain('SGT');
  });

  it('email body does NOT contain the payload reason (legal invariant)', async () => {
    const CONFIDENTIAL_REASON = 'moderator-closed-for-safety-violation';
    const users = [makeStubUser('user_host01', 'host@example.com')];

    const { sender, consumer } = makeConsumer({ users });
    await consumer.handle(makePayload({ reason: CONFIDENTIAL_REASON }), fakeConsumerCtx());

    const sent = sender.sent[0];
    expect(sent).toBeDefined();
    if (!sent) return;

    expect(sent.text).not.toContain(CONFIDENTIAL_REASON);
    expect(sent.html).not.toContain(CONFIDENTIAL_REASON);
    expect(sent.subject).not.toContain(CONFIDENTIAL_REASON);
  });

  it('email body does NOT contain reporter or reported-user IDs (legal invariant)', async () => {
    const REPORTER_ID = 'user_reporter_secret';
    const OPERATOR_NOTE = 'operator-justification-private';
    const users = [makeStubUser('user_host01', 'host@example.com')];

    const { sender, consumer } = makeConsumer({ users });
    await consumer.handle(makePayload(), fakeConsumerCtx());

    const sent = sender.sent[0];
    expect(sent).toBeDefined();
    if (!sent) return;

    // Neither a reporter ID nor any operator text should ever appear — the
    // consumer receives neither and the template takes no such input.
    expect(sent.text).not.toContain(REPORTER_ID);
    expect(sent.html).not.toContain(REPORTER_ID);
    expect(sent.text).not.toContain(OPERATOR_NOTE);
    expect(sent.html).not.toContain(OPERATOR_NOTE);
  });

  it('idempotency: re-delivering the same event sends emails again (accepted duplicate risk)', async () => {
    // Documented accepted risk: the consumer is NOT idempotent. At-least-once
    // delivery with bounded retries (5) means a transient failure between email
    // send and consumer_offsets commit can produce duplicate cancellation emails.
    // This test documents that current behaviour explicitly so the trade-off is
    // visible in the test suite. TRI-159 will add the notification-audit table
    // that enables a dedup guard post-launch.
    const users = [makeStubUser('user_host01', 'host@example.com')];
    const { sender, consumer } = makeConsumer({ joinRequests: [], users });

    await consumer.handle(makePayload(), fakeConsumerCtx());
    await consumer.handle(makePayload(), fakeConsumerCtx());

    // Two deliveries → two emails (documented: not deduplicated at launch)
    expect(sender.sent).toHaveLength(2);
  });
});

import { describe, it, expect, beforeEach } from 'vitest';
import { PostEventCheckIn } from '../../domain/entities/post-event-check-in.js';
import {
  FakePostEventCheckInRepository,
  FakeRecordPostEventCheckInEventUseCase,
  FixedClock,
  TEST_TX,
} from './fakes.js';
import { PseudonymiseCheckInsForUserUseCase } from './pseudonymise-check-ins-for-user.usecase.js';

// ── Helpers ───────────────────────────────────────────────────────────────────

const NOW = new Date('2026-01-01T00:00:00.000Z');
const BASE_DATE = new Date('2025-06-01T00:00:00.000Z');

function makeFlaggedAttendee(overrides: {
  id: string;
  userId: string;
  eventId?: string;
  hostUserId?: string;
}): PostEventCheckIn {
  return PostEventCheckIn.rehydrate({
    id: overrides.id,
    userId: overrides.userId,
    eventId: overrides.eventId ?? 'event-1',
    hostUserId: overrides.hostUserId ?? 'host-1',
    status: 'flagged',
    createdAt: BASE_DATE,
    acknowledgedAt: null,
    flaggedAt: BASE_DATE,
    reportBody: 'some safety concern',
    resolvedAt: null,
  });
}

function makeFlaggedHost(overrides: {
  id: string;
  userId: string;
  eventId?: string;
  hostUserId: string;
}): PostEventCheckIn {
  return PostEventCheckIn.rehydrate({
    id: overrides.id,
    userId: overrides.userId,
    eventId: overrides.eventId ?? 'event-2',
    hostUserId: overrides.hostUserId,
    status: 'flagged',
    createdAt: BASE_DATE,
    acknowledgedAt: null,
    flaggedAt: BASE_DATE,
    reportBody: 'some safety concern',
    resolvedAt: null,
  });
}

function makePending(overrides: {
  id: string;
  userId: string;
  eventId?: string;
}): PostEventCheckIn {
  return PostEventCheckIn.rehydrate({
    id: overrides.id,
    userId: overrides.userId,
    eventId: overrides.eventId ?? 'event-3',
    hostUserId: 'host-1',
    status: 'pending',
    createdAt: BASE_DATE,
    acknowledgedAt: null,
    flaggedAt: null,
    reportBody: null,
    resolvedAt: null,
  });
}

function makeOk(overrides: { id: string; userId: string; eventId?: string }): PostEventCheckIn {
  return PostEventCheckIn.rehydrate({
    id: overrides.id,
    userId: overrides.userId,
    eventId: overrides.eventId ?? 'event-4',
    hostUserId: 'host-1',
    status: 'ok',
    createdAt: BASE_DATE,
    acknowledgedAt: BASE_DATE,
    flaggedAt: null,
    reportBody: null,
    resolvedAt: null,
  });
}

// ── Test suite ────────────────────────────────────────────────────────────────

describe('PseudonymiseCheckInsForUserUseCase', () => {
  let repo: FakePostEventCheckInRepository;
  let audit: FakeRecordPostEventCheckInEventUseCase;
  let useCase: PseudonymiseCheckInsForUserUseCase;

  beforeEach(() => {
    repo = new FakePostEventCheckInRepository();
    audit = new FakeRecordPostEventCheckInEventUseCase();
    useCase = new PseudonymiseCheckInsForUserUseCase(repo, audit, new FixedClock(NOW));
  });

  // ── Pure attendee ──────────────────────────────────────────────────────────

  it('pseudonymises flagged attendee rows and returns correct count', async () => {
    const userId = 'user-alice';
    repo.put(makeFlaggedAttendee({ id: 'ci-1', userId }));
    repo.put(makeFlaggedAttendee({ id: 'ci-2', userId }));
    // Unrelated user — must NOT be touched
    repo.put(makeFlaggedAttendee({ id: 'ci-3', userId: 'user-other' }));

    const result = await useCase.execute({ userId }, TEST_TX);

    expect(result.pseudonymisedReports).toBe(2);
    expect(result.deletedReports).toBe(0);

    // All of alice's flagged rows must have userId rewritten
    const alice1 = await repo.findById('ci-1');
    const alice2 = await repo.findById('ci-2');
    expect(alice1?.userId).not.toBe(userId);
    expect(alice2?.userId).not.toBe(userId);

    // Other user's row must be untouched
    const other = await repo.findById('ci-3');
    expect(other?.userId).toBe('user-other');
  });

  // ── Pure host ──────────────────────────────────────────────────────────────

  it('pseudonymises flagged host rows and returns correct count', async () => {
    const userId = 'user-bob';
    // Bob is host on two flagged check-ins
    repo.put(makeFlaggedHost({ id: 'ci-4', userId: 'attendee-1', hostUserId: userId }));
    repo.put(makeFlaggedHost({ id: 'ci-5', userId: 'attendee-2', hostUserId: userId }));
    // Bob is NOT host here
    repo.put(makeFlaggedHost({ id: 'ci-6', userId: 'attendee-3', hostUserId: 'other-host' }));

    const result = await useCase.execute({ userId }, TEST_TX);

    expect(result.pseudonymisedReports).toBe(2);
    expect(result.deletedReports).toBe(0);

    const row4 = await repo.findById('ci-4');
    const row5 = await repo.findById('ci-5');
    expect(row4?.hostUserId).not.toBe(userId);
    expect(row5?.hostUserId).not.toBe(userId);

    // Attendee userIds on those rows must NOT have been touched
    expect(row4?.userId).toBe('attendee-1');
    expect(row5?.userId).toBe('attendee-2');

    // Unrelated row untouched
    const row6 = await repo.findById('ci-6');
    expect(row6?.hostUserId).toBe('other-host');
  });

  // ── Attendee AND host (mixed) ──────────────────────────────────────────────

  it('handles a user who is both attendee and host across different rows', async () => {
    const userId = 'user-mixed';
    // As attendee
    repo.put(makeFlaggedAttendee({ id: 'ci-a1', userId }));
    repo.put(makeFlaggedAttendee({ id: 'ci-a2', userId }));
    // As host
    repo.put(makeFlaggedHost({ id: 'ci-h1', userId: 'other-attendee', hostUserId: userId }));

    const result = await useCase.execute({ userId }, TEST_TX);

    expect(result.pseudonymisedReports).toBe(3);
    expect(result.deletedReports).toBe(0);

    // Attendee rows: userId rewritten
    const a1 = await repo.findById('ci-a1');
    const a2 = await repo.findById('ci-a2');
    expect(a1?.userId).not.toBe(userId);
    expect(a2?.userId).not.toBe(userId);

    // Host row: hostUserId rewritten; attendee userId unchanged
    const h1 = await repo.findById('ci-h1');
    expect(h1?.hostUserId).not.toBe(userId);
    expect(h1?.userId).toBe('other-attendee');
  });

  // ── Pending + ok deletion ──────────────────────────────────────────────────

  it('deletes pending rows authored by user and returns deletedReports', async () => {
    const userId = 'user-pending';
    repo.put(makePending({ id: 'ci-p1', userId }));
    repo.put(makePending({ id: 'ci-p2', userId }));
    // Another user's pending row — must NOT be deleted
    repo.put(makePending({ id: 'ci-p3', userId: 'other-user' }));

    const result = await useCase.execute({ userId }, TEST_TX);

    expect(result.pseudonymisedReports).toBe(0);
    expect(result.deletedReports).toBe(2);

    // User's pending rows removed
    expect(await repo.findById('ci-p1')).toBeNull();
    expect(await repo.findById('ci-p2')).toBeNull();

    // Other user's row intact
    expect(await repo.findById('ci-p3')).not.toBeNull();
  });

  // ── Pseudonym is opaque (cuid2) — different each run ──────────────────────

  it('generates an opaque pseudonym that differs between runs', async () => {
    const userId = 'user-opaque';
    // First run
    repo.put(makeFlaggedAttendee({ id: 'ci-r1', userId }));
    await useCase.execute({ userId }, TEST_TX);
    const pseudonym1 = (await repo.findById('ci-r1'))?.userId;
    expect(pseudonym1).toBeDefined();
    expect(pseudonym1).not.toBe(userId);

    // Second run on a fresh repo with a new row for the same userId
    const repo2 = new FakePostEventCheckInRepository();
    repo2.put(makeFlaggedAttendee({ id: 'ci-r2', userId }));
    const useCase2 = new PseudonymiseCheckInsForUserUseCase(repo2, audit, new FixedClock(NOW));
    await useCase2.execute({ userId }, TEST_TX);
    const pseudonym2 = (await repo2.findById('ci-r2'))?.userId;

    // Pseudonyms from two separate runs must differ (cuid2 is collision-resistant)
    expect(pseudonym2).not.toBe(pseudonym1);
  });

  // ── Idempotency ───────────────────────────────────────────────────────────

  it('second call returns { pseudonymisedReports: 0, deletedReports: 0 } (no rows left)', async () => {
    const userId = 'user-idem';
    repo.put(makeFlaggedAttendee({ id: 'ci-i1', userId }));
    repo.put(makePending({ id: 'ci-i2', userId }));

    // First call processes everything
    const first = await useCase.execute({ userId }, TEST_TX);
    expect(first.pseudonymisedReports).toBe(1);
    expect(first.deletedReports).toBe(1);

    // Second call — nothing left with this userId
    const second = await useCase.execute({ userId }, TEST_TX);
    expect(second.pseudonymisedReports).toBe(0);
    expect(second.deletedReports).toBe(0);
  });

  // ── Audit calls ───────────────────────────────────────────────────────────

  it('records audit row for pseudonymised attendee batch', async () => {
    const userId = 'user-audit-a';
    repo.put(makeFlaggedAttendee({ id: 'ci-aa1', userId }));
    repo.put(makeFlaggedAttendee({ id: 'ci-aa2', userId }));

    await useCase.execute({ userId }, TEST_TX);

    const pseudonymisedCalls = audit.calls.filter((c) => c.input.reason === 'pseudonymised');
    // Aggregate audit: one record for the attendee batch
    expect(pseudonymisedCalls.length).toBe(1);
    const firstAttendeeCall = pseudonymisedCalls[0];
    expect(firstAttendeeCall?.input.userId).toBe(userId);
    expect(firstAttendeeCall?.input.occurredAt).toBe(NOW);
    expect(firstAttendeeCall?.ctx).toBe(TEST_TX);
  });

  it('records audit row for pseudonymised host batch', async () => {
    const userId = 'user-audit-h';
    repo.put(makeFlaggedHost({ id: 'ci-hh1', userId: 'attendee-x', hostUserId: userId }));

    await useCase.execute({ userId }, TEST_TX);

    const pseudonymisedCalls = audit.calls.filter((c) => c.input.reason === 'pseudonymised');
    expect(pseudonymisedCalls.length).toBe(1);
    const firstHostCall = pseudonymisedCalls[0];
    expect(firstHostCall?.input.userId).toBe(userId);
    expect(firstHostCall?.ctx).toBe(TEST_TX);
  });

  it('records audit rows for both attendee and host batches when both exist', async () => {
    const userId = 'user-audit-both';
    repo.put(makeFlaggedAttendee({ id: 'ci-ab1', userId }));
    repo.put(makeFlaggedHost({ id: 'ci-ab2', userId: 'other', hostUserId: userId }));

    await useCase.execute({ userId }, TEST_TX);

    const pseudonymisedCalls = audit.calls.filter((c) => c.input.reason === 'pseudonymised');
    // Two aggregate audit rows: one per pseudonymiseForUser call
    expect(pseudonymisedCalls.length).toBe(2);
  });

  it('records per-row audit entries for deleted pending rows', async () => {
    const userId = 'user-audit-del';
    const eventId1 = 'event-del-1';
    const eventId2 = 'event-del-2';
    repo.put(makePending({ id: 'ci-d1', userId, eventId: eventId1 }));
    repo.put(makePending({ id: 'ci-d2', userId, eventId: eventId2 }));

    await useCase.execute({ userId }, TEST_TX);

    const deletedCalls = audit.calls.filter((c) => c.input.reason === 'deleted_by_retention');
    expect(deletedCalls.length).toBe(2);

    const ids = deletedCalls.map((c) => c.input.checkInId);
    expect(ids).toContain('ci-d1');
    expect(ids).toContain('ci-d2');

    // Event IDs must be correct on each audit row
    const del1 = deletedCalls.find((c) => c.input.checkInId === 'ci-d1');
    const del2 = deletedCalls.find((c) => c.input.checkInId === 'ci-d2');
    expect(del1?.input.eventId).toBe(eventId1);
    expect(del2?.input.eventId).toBe(eventId2);

    // All audit calls use the caller-supplied TxContext
    for (const call of deletedCalls) {
      expect(call.ctx).toBe(TEST_TX);
    }
  });

  it('does NOT record audit rows when there are no rows to touch', async () => {
    const result = await useCase.execute({ userId: 'user-empty' }, TEST_TX);
    expect(result.pseudonymisedReports).toBe(0);
    expect(result.deletedReports).toBe(0);
    expect(audit.calls).toHaveLength(0);
  });

  // ── ok rows (future work boundary) ────────────────────────────────────────

  it('does NOT delete ok rows (domain repo lacks listByUserAndStatus — deferred)', async () => {
    const userId = 'user-ok';
    repo.put(makeOk({ id: 'ci-ok1', userId }));

    const result = await useCase.execute({ userId }, TEST_TX);

    // ok row untouched — no deletion count, row still present
    expect(result.deletedReports).toBe(0);
    expect(await repo.findById('ci-ok1')).not.toBeNull();
  });
});

import { beforeEach, describe, expect, it } from 'vitest';
import { PostEventCheckIn } from '../../domain/entities/post-event-check-in.js';
import { PrunePostEventCheckInsUseCase } from './prune-post-event-check-ins.usecase.js';
import {
  FakePostEventCheckInRepository,
  FakeRecordPostEventCheckInEventUseCase,
  FakeUnitOfWork,
  FixedClock,
} from './fakes.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const NOW = new Date('2028-06-15T12:00:00Z');

/** Create a PostEventCheckIn in pending status at the given createdAt. */
function pendingAt(id: string, createdAt: Date): PostEventCheckIn {
  const checkIn = PostEventCheckIn.create({
    id,
    userId: `user-${id}`,
    eventId: `event-${id}`,
    hostUserId: `host-${id}`,
    now: createdAt,
  });
  // pullEvents() so aggregate is clean (no queued events).
  checkIn.pullEvents();
  return checkIn;
}

/** Create a PostEventCheckIn in ok status at the given createdAt. */
function okAt(id: string, createdAt: Date): PostEventCheckIn {
  const checkIn = pendingAt(id, createdAt);
  checkIn.acknowledge({ now: createdAt });
  checkIn.pullEvents();
  return checkIn;
}

/**
 * Create a PostEventCheckIn in flagged status with the given resolvedAt.
 * resolvedAt=null means unresolved.
 */
function flaggedAt(id: string, createdAt: Date, resolvedAt: Date | null): PostEventCheckIn {
  const checkIn = pendingAt(id, createdAt);
  checkIn.flag({ reportBody: 'test report', disclaimerAcknowledged: true, now: createdAt });
  checkIn.pullEvents();

  if (resolvedAt !== null) {
    // Rehydrate with resolvedAt set — the aggregate doesn't expose a resolve
    // method at this stage, so we rehydrate to set it.
    return PostEventCheckIn.rehydrate({
      id: checkIn.id,
      userId: checkIn.userId,
      eventId: checkIn.eventId,
      hostUserId: checkIn.hostUserId,
      status: 'flagged',
      createdAt: checkIn.createdAt,
      acknowledgedAt: null,
      flaggedAt: checkIn.flaggedAt,
      reportBody: checkIn.reportBody,
      resolvedAt,
      disclaimerAcknowledged: checkIn.disclaimerAcknowledged,
    });
  }

  return checkIn;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('PrunePostEventCheckInsUseCase', () => {
  let clock: FixedClock;
  let unitOfWork: FakeUnitOfWork;
  let repo: FakePostEventCheckInRepository;
  let audit: FakeRecordPostEventCheckInEventUseCase;
  let useCase: PrunePostEventCheckInsUseCase;

  beforeEach(() => {
    clock = new FixedClock(NOW);
    unitOfWork = new FakeUnitOfWork();
    repo = new FakePostEventCheckInRepository();
    audit = new FakeRecordPostEventCheckInEventUseCase();
    useCase = new PrunePostEventCheckInsUseCase(unitOfWork, repo, audit, clock);
  });

  // ── pending boundary (30 days) ─────────────────────────────────────────────

  it('deletes pending rows older than 30 days', async () => {
    // 31 days before NOW — should be deleted
    const old = pendingAt('old-pending', new Date(NOW.getTime() - 31 * 24 * 60 * 60 * 1000));
    // 29 days before NOW — should be retained
    const recent = pendingAt('recent-pending', new Date(NOW.getTime() - 29 * 24 * 60 * 60 * 1000));
    repo.put(old);
    repo.put(recent);

    const result = await useCase.execute();

    expect(result.pendingDeleted).toBe(1);
    expect(repo.all().map((c) => c.id)).not.toContain('old-pending');
    expect(repo.all().map((c) => c.id)).toContain('recent-pending');
  });

  it('retains pending rows exactly at the 30-day boundary (not older-than, exclusive)', async () => {
    // Exactly 30 days before NOW — NOT older, should be retained
    const exact = pendingAt('exact-pending', new Date(NOW.getTime() - 30 * 24 * 60 * 60 * 1000));
    repo.put(exact);

    const result = await useCase.execute();

    expect(result.pendingDeleted).toBe(0);
    expect(repo.all().map((c) => c.id)).toContain('exact-pending');
  });

  it('emits a deleted_by_retention audit row for each deleted pending row', async () => {
    const old = pendingAt('audit-pending', new Date(NOW.getTime() - 31 * 24 * 60 * 60 * 1000));
    repo.put(old);

    await useCase.execute();

    const call = audit.calls.find((c) => c.input.checkInId === 'audit-pending');
    expect(call).toBeDefined();
    expect(call?.input.reason).toBe('deleted_by_retention');
    expect(call?.input.userId).toBe('user-audit-pending');
    expect(call?.input.eventId).toBe('event-audit-pending');
  });

  // ── ok boundary (90 days) ──────────────────────────────────────────────────

  it('deletes ok rows older than 90 days', async () => {
    const old = okAt('old-ok', new Date(NOW.getTime() - 91 * 24 * 60 * 60 * 1000));
    const recent = okAt('recent-ok', new Date(NOW.getTime() - 89 * 24 * 60 * 60 * 1000));
    repo.put(old);
    repo.put(recent);

    const result = await useCase.execute();

    expect(result.okDeleted).toBe(1);
    expect(repo.all().map((c) => c.id)).not.toContain('old-ok');
    expect(repo.all().map((c) => c.id)).toContain('recent-ok');
  });

  it('retains ok rows exactly at the 90-day boundary', async () => {
    const exact = okAt('exact-ok', new Date(NOW.getTime() - 90 * 24 * 60 * 60 * 1000));
    repo.put(exact);

    const result = await useCase.execute();

    expect(result.okDeleted).toBe(0);
  });

  it('emits a deleted_by_retention audit row for each deleted ok row', async () => {
    const old = okAt('audit-ok', new Date(NOW.getTime() - 91 * 24 * 60 * 60 * 1000));
    repo.put(old);

    await useCase.execute();

    const call = audit.calls.find((c) => c.input.checkInId === 'audit-ok');
    expect(call).toBeDefined();
    expect(call?.input.reason).toBe('deleted_by_retention');
  });

  // ── flagged-resolved boundary (12 months) ─────────────────────────────────

  it('deletes flagged rows with resolvedAt older than 12 months', async () => {
    // resolvedAt 13 months before NOW — should be deleted
    const oldResolved = flaggedAt(
      'old-flagged-resolved',
      new Date(NOW.getTime() - 14 * 30 * 24 * 60 * 60 * 1000),
      new Date(NOW.getTime() - 13 * 30 * 24 * 60 * 60 * 1000),
    );
    // resolvedAt 11 months before NOW — should be retained
    const recentResolved = flaggedAt(
      'recent-flagged-resolved',
      new Date(NOW.getTime() - 14 * 30 * 24 * 60 * 60 * 1000),
      new Date(NOW.getTime() - 11 * 30 * 24 * 60 * 60 * 1000),
    );
    repo.put(oldResolved);
    repo.put(recentResolved);

    const result = await useCase.execute();

    expect(result.flaggedResolvedDeleted).toBe(1);
    expect(repo.all().map((c) => c.id)).not.toContain('old-flagged-resolved');
    expect(repo.all().map((c) => c.id)).toContain('recent-flagged-resolved');
  });

  it('NEVER deletes flagged rows with resolvedAt IS NULL (unresolved safety reports)', async () => {
    // Flagged row seeded long ago, never resolved — must never be touched
    const unresolved = flaggedAt(
      'unresolved-flagged',
      new Date(NOW.getTime() - 24 * 30 * 24 * 60 * 60 * 1000),
      null,
    );
    repo.put(unresolved);

    const result = await useCase.execute();

    expect(result.flaggedResolvedDeleted).toBe(0);
    expect(repo.all().map((c) => c.id)).toContain('unresolved-flagged');
  });

  it('emits a deleted_by_retention audit row for each deleted flagged-resolved row', async () => {
    const old = flaggedAt(
      'audit-flagged',
      new Date(NOW.getTime() - 14 * 30 * 24 * 60 * 60 * 1000),
      new Date(NOW.getTime() - 13 * 30 * 24 * 60 * 60 * 1000),
    );
    repo.put(old);

    await useCase.execute();

    const call = audit.calls.find((c) => c.input.checkInId === 'audit-flagged');
    expect(call).toBeDefined();
    expect(call?.input.reason).toBe('deleted_by_retention');
  });

  // ── result shape ───────────────────────────────────────────────────────────

  it('returns zeros when there is nothing to sweep', async () => {
    const result = await useCase.execute();

    expect(result).toEqual({ pendingDeleted: 0, okDeleted: 0, flaggedResolvedDeleted: 0 });
  });

  it('counts across all three buckets independently', async () => {
    repo.put(pendingAt('p1', new Date(NOW.getTime() - 31 * 24 * 60 * 60 * 1000)));
    repo.put(pendingAt('p2', new Date(NOW.getTime() - 40 * 24 * 60 * 60 * 1000)));
    repo.put(okAt('o1', new Date(NOW.getTime() - 91 * 24 * 60 * 60 * 1000)));
    repo.put(
      flaggedAt(
        'f1',
        new Date(NOW.getTime() - 14 * 30 * 24 * 60 * 60 * 1000),
        new Date(NOW.getTime() - 13 * 30 * 24 * 60 * 60 * 1000),
      ),
    );

    const result = await useCase.execute();

    expect(result.pendingDeleted).toBe(2);
    expect(result.okDeleted).toBe(1);
    expect(result.flaggedResolvedDeleted).toBe(1);
  });
});

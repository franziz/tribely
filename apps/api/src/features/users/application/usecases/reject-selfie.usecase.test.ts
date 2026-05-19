import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { FakeEventPublisher, FakeUnitOfWork, FixedClock } from '@/core/testing/fakes.js';
import type { PhoneNumber } from '@/core/sms/phone-number.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { Email } from '../../domain/value-objects/email.js';
import { DisplayName } from '../../domain/value-objects/display-name.js';
import { User } from '../../domain/entities/user.js';
import { SELFIE_REJECTED } from '../../domain/events/selfie-rejected.event.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import { RejectSelfieUseCase } from './reject-selfie.usecase.js';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeUserRepository implements UserRepository {
  private readonly byId = new Map<string, User>();

  put(user: User): void {
    this.byId.set(user.id, user);
  }

  findById(id: string, _ctx?: TxContext): Promise<User | null> {
    return Promise.resolve(this.byId.get(id) ?? null);
  }

  findByEmail(_email: Email): Promise<User | null> {
    return Promise.resolve(null);
  }

  findByVerifiedPhone(_phone: PhoneNumber): Promise<User | null> {
    return Promise.resolve(null);
  }

  save(user: User, _ctx?: TxContext): Promise<void> {
    this.byId.set(user.id, user);
    return Promise.resolve();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const NOW = new Date('2026-05-01T08:00:00Z');
const USER_ID = 'user_001';

/**
 * Builds a rehydrated User with selfieAttemptCount at the given count.
 * Brief A's cascade fix: rehydrate() requires all selfie fields.
 */
const buildUserWithAttempts = (attemptCount: number): User =>
  User.rehydrate({
    id: USER_ID,
    email: Email.create('alice@example.com'),
    displayName: DisplayName.create('Alice'),
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-01T00:00:00Z'),
    emailVerifiedAt: null,
    bio: null,
    avatarUrl: null,
    languages: [],
    interests: [],
    currentCity: null,
    travelerType: null,
    phone: null,
    phoneVerifiedAt: null,
    selfieStatus: attemptCount > 0 ? 'rejected' : null,
    selfieAttemptCount: attemptCount,
    selfieLastFailureCategory: attemptCount > 0 ? 'poor_lighting' : null,
    selfieAppealLockedAt: attemptCount >= 3 ? NOW : null,
  });

const buildFreshUser = (): User =>
  User.rehydrate({
    id: USER_ID,
    email: Email.create('alice@example.com'),
    displayName: DisplayName.create('Alice'),
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-01T00:00:00Z'),
    emailVerifiedAt: null,
    bio: null,
    avatarUrl: null,
    languages: [],
    interests: [],
    currentCity: null,
    travelerType: null,
    phone: null,
    phoneVerifiedAt: null,
    selfieStatus: null,
    selfieAttemptCount: 0,
    selfieLastFailureCategory: null,
    selfieAppealLockedAt: null,
  });

const buildSut = () => {
  const repo = new FakeUserRepository();
  const publisher = new FakeEventPublisher();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const useCase = new RejectSelfieUseCase(uow, repo, publisher, clock);
  return { repo, publisher, useCase };
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('RejectSelfieUseCase', () => {
  it('returns 404 when user does not exist', async () => {
    const { useCase } = buildSut();
    await expect(
      useCase.execute({ userId: 'missing', failureCategory: 'face_not_visible' }),
    ).rejects.toThrowError(AppError);
  });

  it('increments attemptCount, sets status to rejected, and emits selfieRejected on first rejection', async () => {
    const { repo, publisher, useCase } = buildSut();
    repo.put(buildFreshUser());

    await useCase.execute({ userId: USER_ID, failureCategory: 'poor_lighting' });

    const saved = await repo.findById(USER_ID);
    expect(saved?.selfieAttemptCount).toBe(1);
    expect(saved?.selfieStatus).toBe('rejected');
    expect(saved?.selfieLastFailureCategory).toBe('poor_lighting');
    expect(saved?.selfieAppealLockedAt).toBeNull(); // no lock before 3 attempts

    const events = publisher.published;
    expect(events).toHaveLength(1);
    expect(events[0]?.type).toBe(SELFIE_REJECTED);
    expect(events[0]?.payload).toMatchObject({
      userId: USER_ID,
      failureCategory: 'poor_lighting',
      attemptCount: 1,
      lockedAt: null,
    });
  });

  it('sets selfieAppealLockedAt and includes lockedAt in event payload at attempt 3', async () => {
    const { repo, publisher, useCase } = buildSut();
    // Pre-seed with 2 prior rejections using a different category to allow call 3
    repo.put(
      User.rehydrate({
        id: USER_ID,
        email: Email.create('alice@example.com'),
        displayName: DisplayName.create('Alice'),
        createdAt: new Date('2026-01-01T00:00:00Z'),
        updatedAt: new Date('2026-01-01T00:00:00Z'),
        emailVerifiedAt: null,
        bio: null,
        avatarUrl: null,
        languages: [],
        interests: [],
        currentCity: null,
        travelerType: null,
        phone: null,
        phoneVerifiedAt: null,
        selfieStatus: 'rejected',
        selfieAttemptCount: 2,
        selfieLastFailureCategory: 'face_not_visible', // differs from upcoming call
        selfieAppealLockedAt: null,
      }),
    );

    await useCase.execute({ userId: USER_ID, failureCategory: 'poor_lighting' });

    const saved = await repo.findById(USER_ID);
    expect(saved?.selfieAttemptCount).toBe(3);
    expect(saved?.selfieAppealLockedAt).toEqual(NOW); // locked at attempt 3

    const events = publisher.published;
    expect(events).toHaveLength(1);
    expect(events[0]?.payload).toMatchObject({
      attemptCount: 3,
      lockedAt: NOW.toISOString(),
    });
  });

  it('is idempotent: calling twice with same category after first rejection emits only one event', async () => {
    const { repo, publisher, useCase } = buildSut();
    repo.put(buildFreshUser());

    // First call: processes the rejection
    await useCase.execute({ userId: USER_ID, failureCategory: 'poor_lighting' });
    // Second call: same state (status=rejected, same category, attemptCount>0) → no-op
    await useCase.execute({ userId: USER_ID, failureCategory: 'poor_lighting' });

    const saved = await repo.findById(USER_ID);
    expect(saved?.selfieAttemptCount).toBe(1); // NOT 2
    expect(publisher.published).toHaveLength(1); // only one event emitted
  });

  it('processes a NEW rejection when the category changes (not idempotent across category changes)', async () => {
    const { repo, publisher, useCase } = buildSut();
    repo.put(buildFreshUser());

    await useCase.execute({ userId: USER_ID, failureCategory: 'poor_lighting' });
    await useCase.execute({ userId: USER_ID, failureCategory: 'face_not_visible' });

    const saved = await repo.findById(USER_ID);
    expect(saved?.selfieAttemptCount).toBe(2);
    expect(publisher.published).toHaveLength(2);
  });

  it('uses attemptCount=0 as rejection guard — a fresh user with status=rejected but count=0 proceeds', async () => {
    // Edge case: if somehow a user ends up with status=rejected but count=0 (data anomaly),
    // the idempotency guard does NOT short-circuit (count must be > 0).
    const { repo, publisher, useCase } = buildSut();
    repo.put(
      User.rehydrate({
        id: USER_ID,
        email: Email.create('alice@example.com'),
        displayName: DisplayName.create('Alice'),
        createdAt: new Date('2026-01-01T00:00:00Z'),
        updatedAt: new Date('2026-01-01T00:00:00Z'),
        emailVerifiedAt: null,
        bio: null,
        avatarUrl: null,
        languages: [],
        interests: [],
        currentCity: null,
        travelerType: null,
        phone: null,
        phoneVerifiedAt: null,
        selfieStatus: 'rejected',
        selfieAttemptCount: 0, // anomaly: status rejected but count 0
        selfieLastFailureCategory: 'poor_lighting',
        selfieAppealLockedAt: null,
      }),
    );

    await useCase.execute({ userId: USER_ID, failureCategory: 'poor_lighting' });

    expect(publisher.published).toHaveLength(1);
    const saved = await repo.findById(USER_ID);
    expect(saved?.selfieAttemptCount).toBe(1);
  });

  it('does not emit when the user is already at the same rejected state (full idempotency scenario)', async () => {
    const { repo, publisher, useCase } = buildSut();
    // Pre-seed: already rejected with poor_lighting at count=1 — matches what we'd call
    repo.put(buildUserWithAttempts(1));

    await useCase.execute({ userId: USER_ID, failureCategory: 'poor_lighting' });

    // State unchanged, no event emitted
    expect(publisher.published).toHaveLength(0);
    const saved = await repo.findById(USER_ID);
    expect(saved?.selfieAttemptCount).toBe(1);
  });
});

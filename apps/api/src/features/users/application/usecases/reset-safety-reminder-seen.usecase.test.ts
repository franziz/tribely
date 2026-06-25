import { describe, expect, it } from 'vitest';
import { FakeEventPublisher, FakeUnitOfWork, FixedClock } from '@/core/testing/fakes.js';
import type { PhoneNumber } from '@/core/sms/phone-number.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { Email } from '../../domain/value-objects/email.js';
import { DisplayName } from '../../domain/value-objects/display-name.js';
import { User } from '../../domain/entities/user.js';
import { SAFETY_REMINDER_RESET } from '../../domain/events/safety-reminder-reset.event.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import { ResetSafetyReminderSeenUseCase } from './reset-safety-reminder-seen.usecase.js';

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

  findByIds(ids: string[]): Promise<User[]> {
    const found = ids.flatMap((id) => {
      const u = this.byId.get(id);
      return u ? [u] : [];
    });
    return Promise.resolve(found);
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

const NOW = new Date('2026-06-10T10:00:00Z');
const SEEN_AT = new Date('2026-05-01T08:00:00Z');
const USER_ID = 'user_001';

/** Builds a user whose safetyReminderSeenAt is already set. */
const buildSeenUser = (): User =>
  User.rehydrate({
    id: USER_ID,
    email: Email.create('alice@example.com'),
    displayName: DisplayName.create('Alice'),
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: SEEN_AT,
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
    deletedAt: null,
    isAdmin: false,
    safetyReminderSeenAt: SEEN_AT,
  });

/** Builds a user whose safetyReminderSeenAt is already null. */
const buildUnseenUser = (): User =>
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
    deletedAt: null,
    isAdmin: false,
    safetyReminderSeenAt: null,
  });

const buildSut = () => {
  const repo = new FakeUserRepository();
  const publisher = new FakeEventPublisher();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const useCase = new ResetSafetyReminderSeenUseCase(uow, repo, publisher, clock);
  return { repo, publisher, useCase };
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('ResetSafetyReminderSeenUseCase', () => {
  it('clears the flag and publishes users.safetyReminderReset when the flag is set', async () => {
    const { repo, publisher, useCase } = buildSut();
    repo.put(buildSeenUser());

    await useCase.execute({ userId: USER_ID });

    const saved = await repo.findById(USER_ID);
    expect(saved?.safetyReminderSeenAt).toBeNull();

    expect(publisher.published).toHaveLength(1);
    expect(publisher.published[0]?.type).toBe(SAFETY_REMINDER_RESET);
    expect(publisher.published[0]?.payload).toMatchObject({
      userId: USER_ID,
      resetReason: 'checkInFlagged',
      resetAt: NOW.toISOString(),
    });
  });

  it('is a no-op (no publish) when the flag is already null', async () => {
    const { repo, publisher, useCase } = buildSut();
    repo.put(buildUnseenUser());

    await useCase.execute({ userId: USER_ID });

    const saved = await repo.findById(USER_ID);
    expect(saved?.safetyReminderSeenAt).toBeNull();
    expect(publisher.published).toHaveLength(0);
  });

  it('is a no-op (no throw) when the user does not exist', async () => {
    // Consumer-context: missing user must not poison the consumer offset.
    const { publisher, useCase } = buildSut();

    await expect(useCase.execute({ userId: 'missing' })).resolves.toBeUndefined();
    expect(publisher.published).toHaveLength(0);
  });
});

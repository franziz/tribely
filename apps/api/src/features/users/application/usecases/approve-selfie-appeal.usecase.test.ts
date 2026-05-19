import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { FakeEventPublisher, FakeUnitOfWork, FixedClock } from '@/core/testing/fakes.js';
import type { PhoneNumber } from '@/core/sms/phone-number.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { Email } from '../../domain/value-objects/email.js';
import { DisplayName } from '../../domain/value-objects/display-name.js';
import { User } from '../../domain/entities/user.js';
import { SELFIE_APPEAL_APPROVED } from '../../domain/events/selfie-appeal-approved.event.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import { ApproveSelfieAppealUseCase } from './approve-selfie-appeal.usecase.js';

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

const NOW = new Date('2026-05-15T10:00:00Z');
const LOCKED_AT = new Date('2026-05-01T08:00:00Z');
const USER_ID = 'user_002';

/** A locked user: 3 rejections, selfieAppealLockedAt set. */
const buildLockedUser = (): User =>
  User.rehydrate({
    id: USER_ID,
    email: Email.create('bob@example.com'),
    displayName: DisplayName.create('Bob'),
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: LOCKED_AT,
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
    selfieAttemptCount: 3,
    selfieLastFailureCategory: 'quality_too_low',
    selfieAppealLockedAt: LOCKED_AT,
  });

const buildSut = () => {
  const repo = new FakeUserRepository();
  const publisher = new FakeEventPublisher();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const useCase = new ApproveSelfieAppealUseCase(uow, repo, publisher, clock);
  return { repo, publisher, useCase };
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('ApproveSelfieAppealUseCase', () => {
  it('returns 404 when user does not exist', async () => {
    const { useCase } = buildSut();
    await expect(useCase.execute({ userId: 'missing' })).rejects.toThrowError(AppError);
  });

  it('clears selfieAppealLockedAt and transitions status to pending', async () => {
    const { repo, useCase } = buildSut();
    repo.put(buildLockedUser());

    await useCase.execute({ userId: USER_ID });

    const saved = await repo.findById(USER_ID);
    expect(saved?.selfieAppealLockedAt).toBeNull();
    expect(saved?.selfieStatus).toBe('pending');
  });

  it('preserves selfieAttemptCount — historical record is not reset', async () => {
    const { repo, useCase } = buildSut();
    repo.put(buildLockedUser());

    await useCase.execute({ userId: USER_ID });

    const saved = await repo.findById(USER_ID);
    expect(saved?.selfieAttemptCount).toBe(3); // NOT reset
  });

  it('preserves selfieLastFailureCategory for audit purposes', async () => {
    const { repo, useCase } = buildSut();
    repo.put(buildLockedUser());

    await useCase.execute({ userId: USER_ID });

    const saved = await repo.findById(USER_ID);
    expect(saved?.selfieLastFailureCategory).toBe('quality_too_low'); // NOT cleared
  });

  it('emits selfieAppealApproved event with clearedAt timestamp', async () => {
    const { repo, publisher, useCase } = buildSut();
    repo.put(buildLockedUser());

    await useCase.execute({ userId: USER_ID });

    expect(publisher.published).toHaveLength(1);
    expect(publisher.published[0]?.type).toBe(SELFIE_APPEAL_APPROVED);
    expect(publisher.published[0]?.payload).toMatchObject({
      userId: USER_ID,
      clearedAt: NOW.toISOString(),
    });
  });
});

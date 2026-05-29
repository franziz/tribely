import { describe, expect, it } from 'vitest';
import { FakeUnitOfWork, FixedClock } from '@/core/testing/fakes.js';
import type { PhoneNumber } from '@/core/sms/phone-number.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { Email } from '../../domain/value-objects/email.js';
import { DisplayName } from '../../domain/value-objects/display-name.js';
import { User } from '../../domain/entities/user.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import { PromoteAdminOnBootUseCase } from './promote-admin-on-boot.usecase.js';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeUserRepository implements UserRepository {
  private readonly byId = new Map<string, User>();
  private readonly byEmail = new Map<string, User>();
  saveCallCount = 0;

  put(user: User): void {
    this.byId.set(user.id, user);
    this.byEmail.set(user.email.value, user);
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

  findByEmail(email: Email, _ctx?: TxContext): Promise<User | null> {
    return Promise.resolve(this.byEmail.get(email.value) ?? null);
  }

  findByVerifiedPhone(_phone: PhoneNumber): Promise<User | null> {
    return Promise.resolve(null);
  }

  save(user: User, _ctx?: TxContext): Promise<void> {
    this.saveCallCount += 1;
    this.byId.set(user.id, user);
    this.byEmail.set(user.email.value, user);
    return Promise.resolve();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const NOW = new Date('2026-05-01T10:00:00Z');
const USER_ID = 'user_boot_001';
const USER_EMAIL = 'admin@example.com';

const buildNonAdminUser = (): User =>
  User.rehydrate({
    id: USER_ID,
    email: Email.create(USER_EMAIL),
    displayName: DisplayName.create('Admin User'),
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
  });

const buildAdminUser = (): User =>
  User.rehydrate({
    id: USER_ID,
    email: Email.create(USER_EMAIL),
    displayName: DisplayName.create('Admin User'),
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
    isAdmin: true,
  });

const buildSut = () => {
  const repo = new FakeUserRepository();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const useCase = new PromoteAdminOnBootUseCase(uow, repo, clock);
  return { repo, uow, useCase };
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('PromoteAdminOnBootUseCase', () => {
  describe('outcome: promoted', () => {
    it('returns promoted outcome with userId and email', async () => {
      const { repo, useCase } = buildSut();
      repo.put(buildNonAdminUser());

      const result = await useCase.execute({ email: USER_EMAIL });

      expect(result).toEqual({ outcome: 'promoted', userId: USER_ID, email: USER_EMAIL });
    });

    it('calls save exactly once', async () => {
      const { repo, useCase } = buildSut();
      repo.put(buildNonAdminUser());

      await useCase.execute({ email: USER_EMAIL });

      expect(repo.saveCallCount).toBe(1);
    });

    it('persists isAdmin=true on the saved user', async () => {
      const { repo, useCase } = buildSut();
      repo.put(buildNonAdminUser());

      await useCase.execute({ email: USER_EMAIL });

      const saved = await repo.findById(USER_ID);
      expect(saved?.isAdmin).toBe(true);
    });
  });

  describe('outcome: already-admin', () => {
    it('returns already-admin outcome without calling save', async () => {
      const { repo, useCase } = buildSut();
      repo.put(buildAdminUser());

      const result = await useCase.execute({ email: USER_EMAIL });

      expect(result).toEqual({ outcome: 'already-admin' });
      expect(repo.saveCallCount).toBe(0);
    });
  });

  describe('outcome: no-such-user', () => {
    it('returns no-such-user outcome when no user matches the email', async () => {
      const { useCase } = buildSut();
      // repo is empty — no user seeded

      const result = await useCase.execute({ email: USER_EMAIL });

      expect(result).toEqual({ outcome: 'no-such-user' });
    });

    it('does not call save when no user matches', async () => {
      const { repo, useCase } = buildSut();

      await useCase.execute({ email: USER_EMAIL });

      expect(repo.saveCallCount).toBe(0);
    });

    it('does not throw when no user matches', async () => {
      const { useCase } = buildSut();

      await expect(useCase.execute({ email: USER_EMAIL })).resolves.not.toThrow();
    });
  });

  describe('malformed email', () => {
    it('throws on a malformed email (fail-fast on operator misconfig)', async () => {
      const { useCase } = buildSut();

      await expect(useCase.execute({ email: 'not-an-email' })).rejects.toThrow();
    });
  });
});

import { describe, expect, it, vi } from 'vitest';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import type { HostRatingsReadModel } from '../../domain/ports/host-ratings-read-model.port.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import type { SelfieStatus } from '../../domain/entities/user.js';
import { GetUserCapabilitiesUseCase } from './get-user-capabilities.usecase.js';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

const makeEventRepo = (completedCount: number): EventRepository => {
  const mock: EventRepository = {
    countCompletedByHost: vi.fn().mockResolvedValue(completedCount),
    findById: vi.fn(),
    findByIdForUpdate: vi.fn(),
    save: vi.fn(),
    findManyForListing: vi.fn(),
    pseudonymiseHostForUser: vi.fn().mockResolvedValue(0),
    findCompletedForUserBetween: vi.fn().mockResolvedValue([]),
  };
  return mock;
};

const makeHostRatings = (avgRating: number | null): HostRatingsReadModel => ({
  getAverageRatingForHost: vi.fn().mockResolvedValue(avgRating),
});

/**
 * A UserRepository fake that always returns a user-like object with selfie
 * fields in their default (not approved) state. The original tests for this
 * use case predate TRI-70 and don't exercise canPerformVerifiedAction — the
 * fake satisfies the constructor contract without affecting existing assertions.
 */
const makeUserRepo = (): UserRepository => {
  const fakeUser: { selfieStatus: SelfieStatus | null; selfieAppealLockedAt: Date | null } = {
    selfieStatus: null,
    selfieAppealLockedAt: null,
  };
  const repo: UserRepository = {
    findById: vi.fn().mockResolvedValue(fakeUser),
    findByIds: vi.fn().mockResolvedValue([]),
    findByEmail: vi.fn().mockResolvedValue(null),
    findByVerifiedPhone: vi.fn().mockResolvedValue(null),
    save: vi.fn().mockResolvedValue(undefined),
  };
  return repo;
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('GetUserCapabilitiesUseCase', () => {
  const userId = 'user-abc';

  it('returns false and does NOT call hostRatings when completedCount is 0', async () => {
    const eventRepo = makeEventRepo(0);
    // Capture the spy before passing to the fake so we can assert on it
    // without triggering unbound-method lint (method is referenced via the
    // local variable, not extracted from an object literal).
    const ratingSpy = vi.fn<() => Promise<number | null>>().mockResolvedValue(5.0);
    const hostRatings: HostRatingsReadModel = { getAverageRatingForHost: ratingSpy };
    const useCase = new GetUserCapabilitiesUseCase(eventRepo, hostRatings, makeUserRepo());

    const result = await useCase.execute({ userId });

    expect(result.canPostPrivateVenue).toBe(false);
    // Confirm the ratings query was short-circuited — no wasted DB call.
    expect(ratingSpy).not.toHaveBeenCalled();
  });

  it('returns false when completedCount ≥ 1 but rating is null (no ratings yet)', async () => {
    const useCase = new GetUserCapabilitiesUseCase(
      makeEventRepo(1),
      makeHostRatings(null),
      makeUserRepo(),
    );

    const result = await useCase.execute({ userId });

    expect(result.canPostPrivateVenue).toBe(false);
  });

  it('returns false when completedCount ≥ 1 but rating is below threshold (3.9)', async () => {
    const useCase = new GetUserCapabilitiesUseCase(
      makeEventRepo(1),
      makeHostRatings(3.9),
      makeUserRepo(),
    );

    const result = await useCase.execute({ userId });

    expect(result.canPostPrivateVenue).toBe(false);
  });

  it('returns true when completedCount ≥ 1 and rating equals threshold exactly (4.0)', async () => {
    const useCase = new GetUserCapabilitiesUseCase(
      makeEventRepo(1),
      makeHostRatings(4.0),
      makeUserRepo(),
    );

    const result = await useCase.execute({ userId });

    expect(result.canPostPrivateVenue).toBe(true);
  });

  it('returns true when completedCount ≥ 1 and rating exceeds threshold (4.5)', async () => {
    const useCase = new GetUserCapabilitiesUseCase(
      makeEventRepo(1),
      makeHostRatings(4.5),
      makeUserRepo(),
    );

    const result = await useCase.execute({ userId });

    expect(result.canPostPrivateVenue).toBe(true);
  });
});

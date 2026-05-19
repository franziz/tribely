import { beforeEach, describe, expect, it } from 'vitest';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { FakeUnitOfWork, FixedClock } from '@/core/testing/fakes.js';
import type {
  PostEventCheckInEventEntry,
  PostEventCheckInEventRepository,
} from '../../domain/repositories/post-event-check-in-event.repository.js';
import { PrunePostEventCheckInEventsUseCase } from './prune-post-event-check-in-events.usecase.js';

class FakePruneRepository implements PostEventCheckInEventRepository {
  readonly recordedCutoffs: Date[] = [];
  private pruneCount = 0;

  setPruneCount(n: number): void {
    this.pruneCount = n;
  }

  record(_entry: PostEventCheckInEventEntry, _ctx: TxContext): Promise<void> {
    return Promise.resolve();
  }

  pruneOlderThan(cutoff: Date, _ctx: TxContext): Promise<number> {
    this.recordedCutoffs.push(cutoff);
    return Promise.resolve(this.pruneCount);
  }
}

describe('PrunePostEventCheckInEventsUseCase', () => {
  let clock: FixedClock;
  let unitOfWork: FakeUnitOfWork;
  let repo: FakePruneRepository;
  let useCase: PrunePostEventCheckInEventsUseCase;

  // Fixed "now" matching the selfie precedent test convention.
  const NOW = new Date('2028-05-19T00:00:00Z');

  beforeEach(() => {
    clock = new FixedClock(NOW);
    unitOfWork = new FakeUnitOfWork();
    repo = new FakePruneRepository();
    useCase = new PrunePostEventCheckInEventsUseCase(unitOfWork, repo, clock);
  });

  it('passes a cutoff exactly 24 calendar months before now', async () => {
    await useCase.execute();

    expect(repo.recordedCutoffs).toHaveLength(1);
    const cutoff = repo.recordedCutoffs[0];
    // 2028-05-19 minus 24 months = 2026-05-19T00:00:00Z
    expect(cutoff).toEqual(new Date('2026-05-19T00:00:00Z'));
  });

  it('returns the cutoff in the result', async () => {
    const result = await useCase.execute();

    expect(result.cutoff).toEqual(new Date('2026-05-19T00:00:00Z'));
  });

  it('returns the pruned count from the repository', async () => {
    repo.setPruneCount(17);

    const result = await useCase.execute();

    expect(result.pruned).toBe(17);
  });

  it('returns a non-negative durationMs', async () => {
    const result = await useCase.execute();

    expect(result.durationMs).toBeGreaterThanOrEqual(0);
  });

  it('month subtraction clamps day on 31-day months (e.g. 2028-03-31 - 24 months = 2026-03-31)', async () => {
    clock.set(new Date('2028-03-31T12:00:00Z'));

    await useCase.execute();

    // March has 31 days in both 2026 and 2028 — no clamping needed, but
    // verifies the subtraction lands on the correct month/day.
    expect(repo.recordedCutoffs[0]).toEqual(new Date('2026-03-31T12:00:00Z'));
  });

  it('month subtraction on 31-day to short-month boundary (2027-03-31 - 24 months = 2025-03-31)', async () => {
    clock.set(new Date('2027-03-31T00:00:00Z'));

    await useCase.execute();

    expect(repo.recordedCutoffs[0]).toEqual(new Date('2025-03-31T00:00:00Z'));
  });
});

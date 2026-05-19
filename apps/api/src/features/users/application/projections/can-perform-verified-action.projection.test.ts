import { describe, expect, it } from 'vitest';
import { computeCanPerformVerifiedAction } from './can-perform-verified-action.projection.js';

const lockedAt = new Date('2026-05-01T08:00:00Z');

describe('computeCanPerformVerifiedAction', () => {
  it('returns false when selfieStatus is null (not started)', () => {
    expect(
      computeCanPerformVerifiedAction({ selfieStatus: null, selfieAppealLockedAt: null }),
    ).toBe(false);
  });

  it('returns false when selfieStatus is pending', () => {
    expect(
      computeCanPerformVerifiedAction({ selfieStatus: 'pending', selfieAppealLockedAt: null }),
    ).toBe(false);
  });

  it('returns false when selfieStatus is rejected', () => {
    expect(
      computeCanPerformVerifiedAction({ selfieStatus: 'rejected', selfieAppealLockedAt: null }),
    ).toBe(false);
  });

  it('returns true when selfieStatus is approved and selfieAppealLockedAt is null', () => {
    expect(
      computeCanPerformVerifiedAction({ selfieStatus: 'approved', selfieAppealLockedAt: null }),
    ).toBe(true);
  });

  it('returns false when selfieStatus is approved but selfieAppealLockedAt is set', () => {
    // Defensive: lock takes precedence regardless of status value.
    expect(
      computeCanPerformVerifiedAction({ selfieStatus: 'approved', selfieAppealLockedAt: lockedAt }),
    ).toBe(false);
  });

  it('returns false when selfieStatus is rejected and selfieAppealLockedAt is set', () => {
    expect(
      computeCanPerformVerifiedAction({ selfieStatus: 'rejected', selfieAppealLockedAt: lockedAt }),
    ).toBe(false);
  });
});

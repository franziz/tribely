import { describe, expect, it } from 'vitest';
import { computeIsVerified, type VerificationSignalId } from './is-verified.projection.js';

const now = new Date('2026-01-01T00:00:00.000Z');

describe('computeIsVerified', () => {
  it('returns false for an empty signal set', () => {
    expect(
      computeIsVerified({ emailVerifiedAt: now, phoneVerifiedAt: now, selfieApprovedAt: now }, []),
    ).toBe(false);
  });

  it('returns true for signal set [email] when emailVerifiedAt is set', () => {
    expect(
      computeIsVerified({ emailVerifiedAt: now, phoneVerifiedAt: null, selfieApprovedAt: null }, [
        'email',
      ]),
    ).toBe(true);
  });

  it('returns true for [email,phone,selfie] when all three signals are set', () => {
    expect(
      computeIsVerified({ emailVerifiedAt: now, phoneVerifiedAt: now, selfieApprovedAt: now }, [
        'email',
        'phone',
        'selfie',
      ]),
    ).toBe(true);
  });

  it('returns false for [email,phone,selfie] when phoneVerifiedAt is null', () => {
    expect(
      computeIsVerified({ emailVerifiedAt: now, phoneVerifiedAt: null, selfieApprovedAt: now }, [
        'email',
        'phone',
        'selfie',
      ]),
    ).toBe(false);
  });

  it('returns true for [email,selfie] fallback set when both are set and phoneVerifiedAt is null', () => {
    expect(
      computeIsVerified({ emailVerifiedAt: now, phoneVerifiedAt: null, selfieApprovedAt: now }, [
        'email',
        'selfie',
      ]),
    ).toBe(true);
  });

  it('returns false when an unknown signal ID is present in the set', () => {
    expect(
      computeIsVerified({ emailVerifiedAt: now, phoneVerifiedAt: now, selfieApprovedAt: now }, [
        'email',
        'phone',
        'garbage',
      ] as unknown as VerificationSignalId[]),
    ).toBe(false);
  });
});

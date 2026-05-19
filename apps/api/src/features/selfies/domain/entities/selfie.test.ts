import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { Selfie } from './selfie.js';

const BASE_DATE = new Date('2026-01-01T00:00:00Z');
const NOW = new Date('2026-05-19T10:00:00Z');

const makeSelfie = (
  overrides: Partial<{
    status: 'pending' | 'approved' | 'rejected' | 'deleted';
    storageKey: string | null;
    approvedAt: Date | null;
    rejectedAt: Date | null;
    deletedAt: Date | null;
  }> = {},
): Selfie =>
  Selfie.rehydrate({
    id: 'selfie_01',
    userId: 'user_01',
    status: overrides.status ?? 'pending',
    storageKey:
      overrides.storageKey !== undefined ? overrides.storageKey : 'uploads/user_01/selfie_01.jpg',
    approvedAt: overrides.approvedAt ?? null,
    rejectedAt: overrides.rejectedAt ?? null,
    deletedAt: overrides.deletedAt ?? null,
    createdAt: BASE_DATE,
    updatedAt: BASE_DATE,
  });

describe('Selfie.rehydrate', () => {
  it('round-trips all fields back from the raw state object', () => {
    const selfie = makeSelfie({ status: 'approved', approvedAt: BASE_DATE });

    expect(selfie.id).toBe('selfie_01');
    expect(selfie.userId).toBe('user_01');
    expect(selfie.status).toBe('approved');
    expect(selfie.storageKey).toBe('uploads/user_01/selfie_01.jpg');
    expect(selfie.approvedAt).toEqual(BASE_DATE);
    expect(selfie.rejectedAt).toBeNull();
    expect(selfie.deletedAt).toBeNull();
    expect(selfie.createdAt).toEqual(BASE_DATE);
    expect(selfie.updatedAt).toEqual(BASE_DATE);
    expect(selfie.pullEvents()).toHaveLength(0);
  });
});

describe('Selfie.markDeleted', () => {
  it('transitions a pending selfie to deleted status', () => {
    const selfie = makeSelfie({ status: 'pending' });

    selfie.markDeleted(NOW, 'retention-sweep');

    expect(selfie.status).toBe('deleted');
  });

  it('transitions an approved selfie to deleted status', () => {
    const selfie = makeSelfie({ status: 'approved', approvedAt: BASE_DATE });

    selfie.markDeleted(NOW, 'retention-sweep');

    expect(selfie.status).toBe('deleted');
  });

  it('transitions a rejected selfie to deleted status', () => {
    const selfie = makeSelfie({ status: 'rejected', rejectedAt: BASE_DATE });

    selfie.markDeleted(NOW, 'reviewer-rejection-aged');

    expect(selfie.status).toBe('deleted');
  });

  it('clears storageKey to null on deletion', () => {
    const selfie = makeSelfie({ status: 'pending', storageKey: 'uploads/user_01/selfie_01.jpg' });

    selfie.markDeleted(NOW, 'retention-sweep');

    expect(selfie.storageKey).toBeNull();
  });

  it('preserves the storageKey in the domain event payload so consumers can enqueue the S3 deletion', () => {
    const key = 'uploads/user_01/selfie_01.jpg';
    const selfie = makeSelfie({ status: 'approved', storageKey: key });

    selfie.markDeleted(NOW, 'account-deletion');

    const events = selfie.pullEvents();
    expect(events).toHaveLength(1);
    expect(events[0]?.payload).toMatchObject({ storageKey: key });
  });

  it('sets deletedAt to the supplied now value', () => {
    const selfie = makeSelfie({ status: 'pending' });

    selfie.markDeleted(NOW, 'retention-sweep');

    expect(selfie.deletedAt).toEqual(NOW);
  });

  it('updates updatedAt to the supplied now value', () => {
    const selfie = makeSelfie({ status: 'pending' });

    selfie.markDeleted(NOW, 'retention-sweep');

    expect(selfie.updatedAt).toEqual(NOW);
  });

  it('records a selfies.selfieDeleted event with correct payload shape', () => {
    const selfie = makeSelfie({ status: 'approved', storageKey: 'uploads/u/s.jpg' });

    selfie.markDeleted(NOW, 'account-deletion');

    const events = selfie.pullEvents();
    expect(events).toHaveLength(1);
    const evt = events[0];
    if (!evt) return;
    expect(evt.type).toBe('selfies.selfieDeleted');
    expect(evt.aggregateType).toBe('Selfie');
    expect(evt.aggregateId).toBe('selfie_01');
    expect(evt.payload).toMatchObject({
      selfieId: 'selfie_01',
      userId: 'user_01',
      reason: 'account-deletion',
      storageKey: 'uploads/u/s.jpg',
      deletedAt: NOW.toISOString(),
    });
  });

  it('throws conflict when called on an already-deleted selfie (idempotency guard)', () => {
    const selfie = makeSelfie({ status: 'deleted', deletedAt: BASE_DATE, storageKey: null });

    expect(() => {
      selfie.markDeleted(NOW, 'retention-sweep');
    }).toThrow(AppError);
    try {
      selfie.markDeleted(NOW, 'retention-sweep');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).status).toBe(409);
    }
  });

  it('does not record additional events after throwing on already-deleted (no side effects on throw)', () => {
    const selfie = makeSelfie({ status: 'deleted', deletedAt: BASE_DATE, storageKey: null });

    try {
      selfie.markDeleted(NOW, 'retention-sweep');
    } catch {
      // expected
    }

    expect(selfie.pullEvents()).toHaveLength(0);
  });

  it('handles a selfie with null storageKey at deletion time (emits null in event payload)', () => {
    const selfie = makeSelfie({ status: 'pending', storageKey: null });

    selfie.markDeleted(NOW, 'user-request');

    const events = selfie.pullEvents();
    expect(events[0]?.payload).toMatchObject({ storageKey: null });
  });
});

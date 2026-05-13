import { describe, expect, it } from 'vitest';
import {
  listJoinRequestsByEventQuerySchema,
  rejectJoinRequestBodySchema,
} from './join-request.schemas.js';

describe('rejectJoinRequestBodySchema', () => {
  it('accepts a normal reason', () => {
    expect(rejectJoinRequestBodySchema.parse({ reason: 'Group is too small' })).toEqual({
      reason: 'Group is too small',
    });
  });

  it('rejects an empty reason string', () => {
    expect(() => rejectJoinRequestBodySchema.parse({ reason: '' })).toThrowError();
  });

  it('rejects a reason longer than 500 chars', () => {
    expect(() => rejectJoinRequestBodySchema.parse({ reason: 'x'.repeat(501) })).toThrowError();
  });

  it('rejects a missing reason', () => {
    expect(() => rejectJoinRequestBodySchema.parse({})).toThrowError();
  });
});

describe('listJoinRequestsByEventQuerySchema', () => {
  it('accepts absent status → returns undefined (use case applies default)', () => {
    const result = listJoinRequestsByEventQuerySchema.parse({});
    expect(result.status).toBeUndefined();
  });

  it('accepts a single status string and coerces to array', () => {
    const result = listJoinRequestsByEventQuerySchema.parse({ status: 'approved' });
    expect(result.status).toEqual(['approved']);
  });

  it('accepts an array of status values', () => {
    const result = listJoinRequestsByEventQuerySchema.parse({
      status: ['pending', 'approved'],
    });
    expect(result.status).toEqual(['pending', 'approved']);
  });

  it('rejects an invalid status value', () => {
    expect(() =>
      listJoinRequestsByEventQuerySchema.parse({ status: 'unknown' }),
    ).toThrowError();
  });
});

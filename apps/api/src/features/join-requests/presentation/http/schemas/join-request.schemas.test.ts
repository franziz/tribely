import { describe, expect, it } from 'vitest';
import { rejectJoinRequestBodySchema } from './join-request.schemas.js';

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

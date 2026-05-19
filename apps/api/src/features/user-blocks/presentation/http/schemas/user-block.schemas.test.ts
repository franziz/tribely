import { describe, expect, it } from 'vitest';
import { blockUserBodySchema, listMyBlocksQuerySchema } from './user-block.schemas.js';

describe('blockUserBodySchema', () => {
  it('accepts a valid user ID', () => {
    const result = blockUserBodySchema.safeParse({ blockedUserId: 'somevaliduserid' });
    expect(result.success).toBe(true);
  });

  it('rejects empty blockedUserId', () => {
    const result = blockUserBodySchema.safeParse({ blockedUserId: '' });
    expect(result.success).toBe(false);
  });

  it('rejects missing blockedUserId', () => {
    const result = blockUserBodySchema.safeParse({});
    expect(result.success).toBe(false);
  });
});

describe('listMyBlocksQuerySchema', () => {
  it('defaults limit to 20', () => {
    const result = listMyBlocksQuerySchema.safeParse({});
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.limit).toBe(20);
  });

  it('coerces limit from string', () => {
    const result = listMyBlocksQuerySchema.safeParse({ limit: '5' });
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.limit).toBe(5);
  });

  it('rejects limit > 100', () => {
    const result = listMyBlocksQuerySchema.safeParse({ limit: '200' });
    expect(result.success).toBe(false);
  });
});

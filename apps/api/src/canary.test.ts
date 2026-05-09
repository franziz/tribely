import { describe, expect, it } from 'vitest';

describe('canary', () => {
  it('CI test runner is wired correctly', () => {
    expect(1 + 1).toBe(2);
  });
});

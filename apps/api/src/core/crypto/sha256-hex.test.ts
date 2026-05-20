import { describe, expect, it } from 'vitest';
import { sha256Hex } from './sha256-hex.js';

// Known-good SHA-256 vectors from NIST FIPS 180-4 / RFCs
// sha256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
// sha256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

describe('sha256Hex', () => {
  it('returns a 64-character lowercase hex string', () => {
    const result = sha256Hex('hello world');
    expect(result).toMatch(/^[0-9a-f]{64}$/);
  });

  it('is deterministic: same input always produces the same hash', () => {
    const input = 'user_abc123';
    expect(sha256Hex(input)).toBe(sha256Hex(input));
  });

  it('is sensitive to input changes: different inputs produce different hashes', () => {
    expect(sha256Hex('user_abc')).not.toBe(sha256Hex('user_xyz'));
  });

  it('matches NIST vector: empty string', () => {
    expect(sha256Hex('')).toBe('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
  });

  it('matches NIST vector: "abc"', () => {
    expect(sha256Hex('abc')).toBe(
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
});

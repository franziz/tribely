import { createHash } from 'node:crypto';

/**
 * Generic SHA-256 hex hasher.
 *
 * Returns a 64-character lowercase hex string for any input string.
 * Non-reversible — no lookup table is retained.
 *
 * Usage: user-id pseudonymisation in PDPA s24 audit tables where the audit
 * row must survive user-record deletion but not carry a reversible identity.
 */
export const sha256Hex = (input: string): string =>
  createHash('sha256').update(input).digest('hex');

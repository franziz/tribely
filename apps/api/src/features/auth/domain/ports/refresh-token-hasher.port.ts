/**
 * Outbound port: generate and hash refresh-token secrets.
 *
 * Refresh tokens are opaque high-entropy random strings (NOT JWTs) — the
 * plaintext is shown to the client once at issue time and never stored.
 * Only the hash is persisted, so a database leak doesn't expose live tokens.
 *
 * Refresh tokens are already 256-bit random and don't need argon2-style
 * brute-force resistance — SHA-256 is sufficient and keeps lookups fast.
 */

export interface GeneratedRefreshSecret {
  plaintext: string;
  hash: string;
}

export interface RefreshTokenHasher {
  /** Generate a new random secret and its hash. */
  generate(): GeneratedRefreshSecret;
  /** Hash an existing plaintext secret (for lookup on /auth/refresh). */
  hash(plaintext: string): string;
}

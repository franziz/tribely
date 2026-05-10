/**
 * Generates and hashes one-time verification codes.
 *
 * Codes are 6-digit numeric strings (zero-padded), comparable to the OTP
 * codes Singapore users see from Grab, DBS, etc. The plaintext is shown to
 * the user via email; only the hash is persisted.
 *
 * Why a port: the use case shouldn't pull node:crypto directly — keeps the
 * domain testable with a deterministic fake and lets us swap the digest
 * (e.g. add a server-side pepper later) without touching application code.
 */
export interface GeneratedVerificationCode {
  plaintext: string;
  hash: string;
}

export interface VerificationCodeHasher {
  generate(): GeneratedVerificationCode;
  hash(plaintext: string): string;
}

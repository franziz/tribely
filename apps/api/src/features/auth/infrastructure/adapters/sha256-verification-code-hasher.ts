import { createHash, randomInt } from 'node:crypto';
import type {
  GeneratedVerificationCode,
  VerificationCodeHasher,
} from '../../domain/ports/verification-code-hasher.port.js';

/**
 * Verification-code generator + hasher.
 *
 * - Plaintext: 6-digit numeric, zero-padded. Search space is 1,000,000 —
 *   sufficient because (a) verify is auth-required so codes are scoped to a
 *   single userId and (b) the token aggregate caps wrong attempts at 5.
 * - Hash: SHA-256 of the plaintext, hex-encoded. Stored in
 *   `email_verification_tokens.codeHash`.
 *
 * Uses `crypto.randomInt` (CSPRNG, unbiased over [0, 1_000_000)) rather than
 * `Math.random()` or modulo-bias tricks.
 */
export class Sha256VerificationCodeHasher implements VerificationCodeHasher {
  generate(): GeneratedVerificationCode {
    const n = randomInt(0, 1_000_000);
    const plaintext = n.toString().padStart(6, '0');
    return { plaintext, hash: this.hash(plaintext) };
  }

  hash(plaintext: string): string {
    return createHash('sha256').update(plaintext).digest('hex');
  }
}

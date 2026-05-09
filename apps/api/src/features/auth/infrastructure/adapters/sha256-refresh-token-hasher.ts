import { createHash, randomBytes } from 'node:crypto';
import type {
  GeneratedRefreshSecret,
  RefreshTokenHasher,
} from '../../domain/ports/refresh-token-hasher.port.js';

/**
 * Refresh-token secret generator + hasher.
 *
 * - Plaintext: 32 bytes (256 bits) of cryptographic random, base64url-encoded
 *   for safe transport in JSON bodies. ~43 chars.
 * - Hash: SHA-256 of the plaintext, hex-encoded. Stored in `refresh_tokens.tokenHash`.
 *
 * Why not argon2? Argon2 is for low-entropy human-chosen passwords. Refresh
 * tokens are already high-entropy random — SHA-256 is sufficient and lookups
 * stay fast.
 */
export class Sha256RefreshTokenHasher implements RefreshTokenHasher {
  generate(): GeneratedRefreshSecret {
    const plaintext = randomBytes(32).toString('base64url');
    return { plaintext, hash: this.hash(plaintext) };
  }

  hash(plaintext: string): string {
    return createHash('sha256').update(plaintext).digest('hex');
  }
}

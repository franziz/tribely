import type { Password } from '../value-objects/password.js';
import type { HashedPassword } from '../value-objects/hashed-password.js';

/**
 * Outbound port: hashes plaintext passwords and verifies them.
 * Implementation choice (argon2 / bcrypt / scrypt) is infrastructure.
 */
export interface PasswordHasher {
  hash(plaintext: Password): Promise<HashedPassword>;
  verify(plaintext: Password, hashed: HashedPassword): Promise<boolean>;
}

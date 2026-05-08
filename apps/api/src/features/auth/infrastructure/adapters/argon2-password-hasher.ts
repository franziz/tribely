import argon2 from 'argon2';
import type { PasswordHasher } from '../../domain/ports/password-hasher.port.js';
import { HashedPassword } from '../../domain/value-objects/hashed-password.js';
import type { Password } from '../../domain/value-objects/password.js';

export class Argon2PasswordHasher implements PasswordHasher {
  async hash(plaintext: Password): Promise<HashedPassword> {
    const hash = await argon2.hash(plaintext.value);
    return HashedPassword.fromHash(hash);
  }

  verify(plaintext: Password, hashed: HashedPassword): Promise<boolean> {
    return argon2.verify(hashed.value, plaintext.value);
  }
}

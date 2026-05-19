import { createHash } from 'node:crypto';
import type { E164Phone } from './phone-number.js';
import type { PhoneHasher } from './phone-hasher.port.js';

export class Sha256PhoneHasher implements PhoneHasher {
  constructor(private readonly salt: string) {
    if (salt.length < 32) {
      throw new Error('PHONE_HASH_SALT must be at least 32 characters');
    }
  }

  hash(phone: E164Phone): string {
    return createHash('sha256')
      .update(this.salt + phone)
      .digest('hex');
  }
}

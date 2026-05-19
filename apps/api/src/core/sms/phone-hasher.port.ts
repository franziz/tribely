import type { E164Phone } from './phone-number.js';

export interface PhoneHasher {
  hash(phone: E164Phone): string;
}

import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { PhoneNumber } from '@/core/sms/phone-number.js';
import type { User } from '../entities/user.js';
import type { Email } from '../value-objects/email.js';

export interface UserRepository {
  findById(id: string, ctx?: TxContext): Promise<User | null>;
  findByEmail(email: Email, ctx?: TxContext): Promise<User | null>;
  /**
   * Returns the user whose phone is verified with the given number, or null if
   * no such user exists. Uses the partial unique index on (phone, phoneVerifiedAt)
   * from SWE-2 — at most one row can match. Uses `findFirst` (not `findUnique`)
   * because Prisma client does not model partial uniques as queryable uniques.
   */
  findByVerifiedPhone(phone: PhoneNumber, ctx?: TxContext): Promise<User | null>;
  save(user: User, ctx?: TxContext): Promise<void>;
}

import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { User } from '../entities/user.js';
import type { Email } from '../value-objects/email.js';

export interface UserRepository {
  findById(id: string, ctx?: TxContext): Promise<User | null>;
  findByEmail(email: Email, ctx?: TxContext): Promise<User | null>;
  save(user: User, ctx?: TxContext): Promise<void>;
}

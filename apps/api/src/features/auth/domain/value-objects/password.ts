import { AppError } from '@/core/errors/app-error.js';

/**
 * Plaintext password — only exists transiently during sign-up / sign-in.
 * Enforces strength rules. Never persisted; HashedPassword is what the
 * Credential aggregate stores.
 */
export class Password {
  private constructor(public readonly value: string) {}

  static create(raw: string): Password {
    if (raw.length < Password.MIN || raw.length > Password.MAX) {
      throw AppError.validation(`Password must be ${Password.MIN}-${Password.MAX} characters`);
    }
    return new Password(raw);
  }

  static readonly MIN = 8;
  static readonly MAX = 128;
}

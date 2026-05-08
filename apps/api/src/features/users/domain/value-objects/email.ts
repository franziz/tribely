import { AppError } from '@/core/errors/app-error.js';

/**
 * Email value object. Normalizes (trim + lowercase) and validates format.
 * Identity is its normalized string value — two Emails with the same value are equal.
 */
export class Email {
  private constructor(public readonly value: string) {}

  static create(raw: string): Email {
    const normalized = raw.trim().toLowerCase();
    if (!Email.RE.test(normalized)) {
      throw AppError.validation(`Invalid email: ${raw}`);
    }
    return new Email(normalized);
  }

  equals(other: Email): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }

  // Pragmatic, not RFC 5322 — sufficient for application-level validation.
  private static readonly RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
}

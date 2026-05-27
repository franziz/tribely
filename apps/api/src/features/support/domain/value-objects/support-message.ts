import { AppError } from '@/core/errors/app-error.js';

const MAX_LENGTH = 4000;

/**
 * SupportMessage value object.
 *
 * Identity is its trimmed value — two SupportMessages with the same trimmed
 * content are equal. Rejects empty strings and pure whitespace.
 * Construct via SupportMessage.create(raw); never `new SupportMessage(...)`.
 */
export class SupportMessage {
  private constructor(public readonly value: string) {}

  static create(raw: string): SupportMessage {
    const normalized = raw.trim();

    if (normalized.length === 0) {
      throw AppError.validation('SupportMessage must not be empty or pure whitespace');
    }

    if (normalized.length > MAX_LENGTH) {
      throw AppError.validation(
        `SupportMessage must not exceed ${String(MAX_LENGTH)} characters (got ${String(normalized.length)})`,
      );
    }

    return new SupportMessage(normalized);
  }

  equals(other: SupportMessage): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

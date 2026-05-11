import { AppError } from '@/core/errors/app-error.js';

/**
 * Bio value object.
 *
 * Optional free-text self-description. Max 300 chars. Stored trimmed.
 * Identity is its normalized value.
 */
export class Bio {
  static readonly MAX = 300;

  private constructor(public readonly value: string) {}

  static create(raw: string): Bio {
    const trimmed = raw.trim();
    if (trimmed.length === 0) {
      throw AppError.validation('Bio must not be blank');
    }
    if (trimmed.length > Bio.MAX) {
      throw AppError.validation(`Bio must be at most ${String(Bio.MAX)} characters`);
    }
    return new Bio(trimmed);
  }

  equals(other: Bio): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

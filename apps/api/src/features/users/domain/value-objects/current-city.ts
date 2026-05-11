import { AppError } from '@/core/errors/app-error.js';

/**
 * CurrentCity value object.
 *
 * Free-text city name the user is currently based in or traveling through.
 * Trimmed on input; max 80 characters; must not be empty after trimming.
 */
export class CurrentCity {
  static readonly MAX = 80;

  private constructor(public readonly value: string) {}

  static create(raw: string): CurrentCity {
    const trimmed = raw.trim();
    if (trimmed.length === 0) {
      throw AppError.validation('Current city must not be empty');
    }
    if (trimmed.length > CurrentCity.MAX) {
      throw AppError.validation(
        `Current city must be at most ${String(CurrentCity.MAX)} characters`,
      );
    }
    return new CurrentCity(trimmed);
  }

  equals(other: CurrentCity): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

import { AppError } from '@/core/errors/app-error.js';

/**
 * Star rating for a review. Valid integer values: 1, 2, 3, 4, 5.
 *
 * Non-integer inputs and out-of-range values are rejected with a validation
 * error. Private constructor enforces the creation invariant — callers must
 * use `Rating.create()`.
 */
export class Rating {
  private constructor(public readonly value: number) {}

  static readonly MIN = 1;
  static readonly MAX = 5;

  static create(value: number): Rating {
    if (!Number.isInteger(value)) {
      throw AppError.validation(`Rating must be an integer, got: ${String(value)}`);
    }
    if (value < Rating.MIN || value > Rating.MAX) {
      throw AppError.validation(
        `Rating must be between ${String(Rating.MIN)} and ${String(Rating.MAX)}, got: ${String(value)}`,
      );
    }
    return new Rating(value);
  }

  equals(other: Rating): boolean {
    return this.value === other.value;
  }
}

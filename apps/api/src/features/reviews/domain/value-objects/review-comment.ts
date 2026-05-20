import { AppError } from '@/core/errors/app-error.js';

/**
 * Optional free-text comment on a review. Max 500 chars.
 *
 * `ReviewComment.create(value)` returns `null` for empty / whitespace-only
 * input — the use case treats absence and empty as the same thing. This lets
 * domain code use `ReviewComment | null` cleanly without a separate empty
 * sentinel type.
 *
 * Private constructor enforces the creation invariant.
 */
export class ReviewComment {
  private constructor(public readonly value: string) {}

  static readonly MAX_LENGTH = 500;

  /**
   * Returns `null` for empty / whitespace-only strings, or a validated
   * `ReviewComment` for non-empty strings within the length limit.
   */
  static create(value: string): ReviewComment | null {
    const trimmed = value.trim();
    if (trimmed.length === 0) {
      return null;
    }
    if (trimmed.length > ReviewComment.MAX_LENGTH) {
      throw AppError.validation(
        `Review comment must be at most ${String(ReviewComment.MAX_LENGTH)} characters`,
      );
    }
    return new ReviewComment(trimmed);
  }

  equals(other: ReviewComment): boolean {
    return this.value === other.value;
  }
}

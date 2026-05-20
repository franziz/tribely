import { AppError } from '@/core/errors/app-error.js';

/**
 * Optional free-text comment on a report. Max 500 chars.
 *
 * `ReportComment.create(value)` returns `null` for null/undefined/empty/
 * whitespace-only input — the use case treats absence and empty as
 * equivalent. This lets domain code use `ReportComment | null` cleanly.
 *
 * Private constructor enforces the creation invariant.
 */
export class ReportComment {
  private constructor(public readonly value: string) {}

  static readonly MAX_LENGTH = 500;

  /**
   * Returns `null` for null/undefined/empty/whitespace-only strings, or a
   * validated `ReportComment` for non-empty strings within the length limit.
   */
  static create(value: string | null | undefined): ReportComment | null {
    if (value === null || value === undefined) return null;
    const trimmed = value.trim();
    if (trimmed.length === 0) return null;
    if (trimmed.length > ReportComment.MAX_LENGTH) {
      throw AppError.validation(
        `Report comment must be at most ${String(ReportComment.MAX_LENGTH)} characters`,
      );
    }
    return new ReportComment(trimmed);
  }

  equals(other: ReportComment): boolean {
    return this.value === other.value;
  }
}

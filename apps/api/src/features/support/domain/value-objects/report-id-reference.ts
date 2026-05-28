import { AppError } from '@/core/errors/app-error.js';

const MAX_LENGTH = 64;

/**
 * ReportIdReference value object.
 *
 * Free-text reference to a moderation report (NOT a foreign key — legal-compliance
 * guardrail prevents support_tickets from joining moderation_reports).
 * Non-empty when present; max 64 chars.
 * Construct via ReportIdReference.create(raw); never `new ReportIdReference(...)`.
 */
export class ReportIdReference {
  private constructor(public readonly value: string) {}

  static create(raw: string): ReportIdReference {
    const normalized = raw.trim();

    if (normalized.length === 0) {
      throw AppError.validation('ReportIdReference must not be empty when provided');
    }

    if (normalized.length > MAX_LENGTH) {
      throw AppError.validation(
        `ReportIdReference must not exceed ${String(MAX_LENGTH)} characters (got ${String(normalized.length)})`,
      );
    }

    return new ReportIdReference(normalized);
  }

  equals(other: ReportIdReference): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

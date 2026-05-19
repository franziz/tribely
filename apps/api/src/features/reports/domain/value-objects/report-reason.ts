import { AppError } from '@/core/errors/app-error.js';

/**
 * Enum of valid reasons a user can give when filing a report.
 *
 * Stored as a plain string column with a DB CHECK constraint so future
 * values need only a migration, not a schema enum change.
 */
export const REPORT_REASON_VALUES = [
  'harassment',
  'hate_speech',
  'sexual_content',
  'personal_information_disclosure',
  'false_information',
  'spam',
  'other',
] as const;

export type ReportReasonValue = (typeof REPORT_REASON_VALUES)[number];

export class ReportReason {
  private constructor(public readonly value: ReportReasonValue) {}

  static create(value: string): ReportReason {
    if (!(REPORT_REASON_VALUES as readonly string[]).includes(value)) {
      throw AppError.validation(
        `Invalid report reason: "${value}". Must be one of: ${REPORT_REASON_VALUES.join(', ')}`,
      );
    }
    return new ReportReason(value as ReportReasonValue);
  }

  equals(other: ReportReason): boolean {
    return this.value === other.value;
  }
}

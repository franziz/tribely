import { AppError } from '@/core/errors/app-error.js';

/**
 * SupportCategory value object.
 *
 * Identity is its normalized value — two SupportCategorys with the same value are equal.
 * Construct via SupportCategory.create(raw); never `new SupportCategory(...)`.
 */
export const SUPPORT_CATEGORIES = [
  'report_followup_7d',
  'account_signin',
  'event_or_host',
  'app_broken',
  'feedback',
  'other',
] as const;

export type SupportCategoryValue = (typeof SUPPORT_CATEGORIES)[number];

export class SupportCategory {
  private constructor(public readonly value: SupportCategoryValue) {}

  static create(raw: string): SupportCategory {
    const normalized = raw.trim();
    if (!SUPPORT_CATEGORIES.includes(normalized as SupportCategoryValue)) {
      throw AppError.validation(
        `Invalid SupportCategory: "${raw}". Must be one of: ${SUPPORT_CATEGORIES.join(', ')}`,
      );
    }
    return new SupportCategory(normalized as SupportCategoryValue);
  }

  equals(other: SupportCategory): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

/**
 * SelfieFailureCategory — string literal union + type guard.
 *
 * NOT a value-object class. Stored as TEXT with a CHECK constraint in Postgres
 * (same convention as TravelerType, EventCategory, etc.). The DB enforces the
 * valid values; this module provides compile-time narrowing and a runtime guard
 * for use in the mapper when rehydrating from persistence.
 *
 * Values:
 *   - poor_lighting      — face present but lighting makes it unusable
 *   - face_not_visible   — face not clearly in frame
 *   - quality_too_low    — image resolution/blur below acceptable threshold
 *   - other              — catch-all for manual review edge cases
 */
export type SelfieFailureCategory =
  | 'poor_lighting'
  | 'face_not_visible'
  | 'quality_too_low'
  | 'other';

const VALID_SELFIE_FAILURE_CATEGORIES = new Set<SelfieFailureCategory>([
  'poor_lighting',
  'face_not_visible',
  'quality_too_low',
  'other',
]);

export function isSelfieFailureCategory(v: string): v is SelfieFailureCategory {
  return VALID_SELFIE_FAILURE_CATEGORIES.has(v as SelfieFailureCategory);
}

export const SELFIE_FAILURE_CATEGORIES: readonly SelfieFailureCategory[] = [
  'poor_lighting',
  'face_not_visible',
  'quality_too_low',
  'other',
];

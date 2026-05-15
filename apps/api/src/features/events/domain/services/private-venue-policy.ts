import { type VenueCategory } from '../value-objects/venue-category.js';

export type PrivateVenueReason = 'category_not_public' | 'keyword_match';

export interface PrivateVenueDetection {
  isPrivate: boolean;
  reason: PrivateVenueReason | null;
  matchedKeyword: string | null;
}

/**
 * Keywords that indicate a private/residential venue when found in the venue name.
 * Sorted longest-first for greedy matching — a more specific keyword wins over a
 * shorter one embedded inside it (e.g. "condominium" before "condo").
 *
 * NOTE: "block" is intentionally absent — HDB block addresses ("Block 335 Smith St")
 * are public and would produce false positives for Singapore users.
 */
export const PRIVATE_KEYWORDS = [
  'condominium',
  'apartment',
  'my place',
  'my flat',
  'my room',
  'airbnb',
  'studio',
  'hostel',
  'condo',
  'hotel',
  'motel',
  'house',
  'home',
  'unit',
  'apt',
] as const satisfies readonly string[];

/**
 * Pure function — no IO, no clock.
 *
 * Determines whether a venue (described by its category + name) is considered
 * private under Tribely's venue policy.
 *
 * Algorithm:
 * 1. If the category is not in the public allowlist → `category_not_public`.
 * 2. Else, if the venue name contains any keyword from `PRIVATE_KEYWORDS` (case-
 *    insensitive substring match, longest keyword wins) → `keyword_match`.
 * 3. Otherwise → not private.
 */
export const detectPrivateVenue = (input: {
  category: VenueCategory;
  venueName: string;
}): PrivateVenueDetection => {
  if (!input.category.isPublic()) {
    return { isPrivate: true, reason: 'category_not_public', matchedKeyword: null };
  }

  const lower = input.venueName.toLowerCase();
  for (const keyword of PRIVATE_KEYWORDS) {
    if (lower.includes(keyword)) {
      return { isPrivate: true, reason: 'keyword_match', matchedKeyword: keyword };
    }
  }

  return { isPrivate: false, reason: null, matchedKeyword: null };
};

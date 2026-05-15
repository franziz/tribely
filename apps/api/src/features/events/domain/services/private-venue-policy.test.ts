import { describe, expect, it } from 'vitest';
import { VenueCategory } from '../value-objects/venue-category.js';
import { PRIVATE_KEYWORDS, detectPrivateVenue } from './private-venue-policy.js';

describe('detectPrivateVenue', () => {
  describe('public category + clean name → not private', () => {
    it.each(VenueCategory.PUBLIC_VALUES)(
      'returns isPrivate=false for public category "%s" with a clean name',
      (value) => {
        const result = detectPrivateVenue({
          category: VenueCategory.create(value),
          venueName: 'Gardens by the Bay',
        });
        expect(result).toEqual({ isPrivate: false, reason: null, matchedKeyword: null });
      },
    );
  });

  describe('private category → category_not_public', () => {
    const privateValues = VenueCategory.VALUES.filter(
      (v) => !(VenueCategory.PUBLIC_VALUES as readonly string[]).includes(v),
    );

    it.each(privateValues)(
      'returns category_not_public for private category "%s"',
      (value) => {
        const result = detectPrivateVenue({
          category: VenueCategory.create(value),
          venueName: 'Some Venue',
        });
        expect(result).toEqual({
          isPrivate: true,
          reason: 'category_not_public',
          matchedKeyword: null,
        });
      },
    );
  });

  describe('keyword matching — case-insensitive substring', () => {
    it.each(PRIVATE_KEYWORDS)(
      'matches keyword "%s" in lowercase',
      (keyword) => {
        const result = detectPrivateVenue({
          category: VenueCategory.create('park'),
          venueName: `near the ${keyword} entrance`,
        });
        expect(result).toEqual({
          isPrivate: true,
          reason: 'keyword_match',
          matchedKeyword: keyword,
        });
      },
    );

    it.each(PRIVATE_KEYWORDS)(
      'matches keyword "%s" in UPPERCASE',
      (keyword) => {
        const result = detectPrivateVenue({
          category: VenueCategory.create('park'),
          venueName: keyword.toUpperCase(),
        });
        expect(result).toEqual({
          isPrivate: true,
          reason: 'keyword_match',
          matchedKeyword: keyword,
        });
      },
    );

    it.each(PRIVATE_KEYWORDS)(
      'matches keyword "%s" in mixed case',
      (keyword) => {
        // Toggle case of each character for a mixed-case variant
        const mixed = keyword
          .split('')
          .map((ch, i) => (i % 2 === 0 ? ch.toUpperCase() : ch.toLowerCase()))
          .join('');
        const result = detectPrivateVenue({
          category: VenueCategory.create('park'),
          venueName: `My ${mixed} nearby`,
        });
        expect(result).toEqual({
          isPrivate: true,
          reason: 'keyword_match',
          matchedKeyword: keyword,
        });
      },
    );
  });

  describe('HDB false-positive guard', () => {
    it('does NOT flag "block" in a typical HDB address', () => {
      const result = detectPrivateVenue({
        category: VenueCategory.create('hawker_centre'),
        venueName: 'Block 335 Smith Street Hawker Centre',
      });
      expect(result).toEqual({ isPrivate: false, reason: null, matchedKeyword: null });
    });
  });

  describe('priority: category_not_public wins over keyword match', () => {
    it('returns category_not_public when category is private AND name contains a keyword', () => {
      // category=apartment (private) + name contains "apartment" keyword
      const result = detectPrivateVenue({
        category: VenueCategory.create('apartment'),
        venueName: 'My Apartment block 3',
      });
      expect(result).toEqual({
        isPrivate: true,
        reason: 'category_not_public',
        matchedKeyword: null,
      });
    });
  });

  describe('specific case-insensitive spot-checks', () => {
    it('"MY APARTMENT" matches apartment keyword', () => {
      const result = detectPrivateVenue({
        category: VenueCategory.create('park'),
        venueName: 'MY APARTMENT',
      });
      expect(result).toEqual({
        isPrivate: true,
        reason: 'keyword_match',
        matchedKeyword: 'apartment',
      });
    });

    it('"My ApArTmEnT" matches apartment keyword', () => {
      const result = detectPrivateVenue({
        category: VenueCategory.create('park'),
        venueName: 'My ApArTmEnT',
      });
      expect(result).toEqual({
        isPrivate: true,
        reason: 'keyword_match',
        matchedKeyword: 'apartment',
      });
    });
  });
});

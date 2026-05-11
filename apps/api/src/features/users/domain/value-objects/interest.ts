import { AppError } from '@/core/errors/app-error.js';

/**
 * Interest value object.
 *
 * Represents one activity category a user is interested in.
 * Validated against the platform's supported picklist so that interests can
 * drive discovery matching without free-text noise.
 */
export class Interest {
  static readonly VALID_CODES: ReadonlySet<string> = new Set([
    'drinks',
    'food',
    'coffee',
    'hike',
    'cycling',
    'running',
    'yoga',
    'gym',
    'swimming',
    'team_sports',
    'museum',
    'art',
    'music',
    'theatre',
    'film',
    'board_games',
    'photography',
    'reading',
    'cooking',
    'language_exchange',
    'travel',
    'nightlife',
    'beach',
    'nature',
    'tech',
    'startups',
    'finance',
    'volunteering',
    'wellness',
    'other',
  ]);

  private constructor(public readonly value: string) {}

  static create(raw: string): Interest {
    const normalized = raw.trim().toLowerCase();
    if (!Interest.VALID_CODES.has(normalized)) {
      throw AppError.validation(`Unsupported interest: ${raw}`);
    }
    return new Interest(normalized);
  }

  equals(other: Interest): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

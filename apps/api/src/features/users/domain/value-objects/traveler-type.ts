import { AppError } from '@/core/errors/app-error.js';

/**
 * TravelerType value object.
 *
 * Describes how the user currently relates to a location:
 *   - local      — lives here long-term
 *   - traveling  — passing through / short-stay visitor
 *   - expat      — living abroad outside their home country
 */
export type TravelerTypeValue = 'local' | 'traveling' | 'expat';

const VALID_VALUES = new Set<TravelerTypeValue>(['local', 'traveling', 'expat']);

export class TravelerType {
  static readonly VALID_VALUES = VALID_VALUES;

  private constructor(public readonly value: TravelerTypeValue) {}

  static create(raw: string): TravelerType {
    if (!VALID_VALUES.has(raw as TravelerTypeValue)) {
      throw AppError.validation(
        `Traveler type must be one of: ${[...VALID_VALUES].join(', ')}. Got: ${raw}`,
      );
    }
    return new TravelerType(raw as TravelerTypeValue);
  }

  equals(other: TravelerType): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

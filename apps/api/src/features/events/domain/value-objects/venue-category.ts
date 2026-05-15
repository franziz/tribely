import { AppError } from '@/core/errors/app-error.js';

export type VenueCategoryValue =
  | 'hawker_centre'
  | 'park'
  | 'museum'
  | 'restaurant'
  | 'bar'
  | 'cafe'
  | 'beach'
  | 'mrt_landmark'
  | 'library'
  | 'community_centre'
  | 'shopping_mall_common_area'
  | 'tourist_attraction'
  | 'apartment'
  | 'condo'
  | 'home'
  | 'hotel'
  | 'hostel'
  | 'other';

/**
 * Venue category — closed enum. Public values are freely usable; private values
 * require the host to have `canPostPrivateVenue=true` on their profile.
 * Use `VenueCategory.VALUES` to drive Zod schemas / select inputs.
 * Use `VenueCategory.PUBLIC_VALUES` for the allowlist of categories that do not
 * require the private-venue permission.
 */
export class VenueCategory {
  private constructor(private readonly _value: VenueCategoryValue) {}

  get value(): VenueCategoryValue {
    return this._value;
  }

  static create(raw: string): VenueCategory {
    if (!VenueCategory.isValid(raw)) {
      throw AppError.validation(
        `Invalid venue category: ${raw} (valid: ${VenueCategory.VALUES.join(', ')})`,
      );
    }
    return new VenueCategory(raw);
  }

  static isValid(raw: string): raw is VenueCategoryValue {
    return (VenueCategory.VALUES as readonly string[]).includes(raw);
  }

  static readonly VALUES = [
    'hawker_centre',
    'park',
    'museum',
    'restaurant',
    'bar',
    'cafe',
    'beach',
    'mrt_landmark',
    'library',
    'community_centre',
    'shopping_mall_common_area',
    'tourist_attraction',
    'apartment',
    'condo',
    'home',
    'hotel',
    'hostel',
    'other',
  ] as const satisfies readonly VenueCategoryValue[];

  static readonly PUBLIC_VALUES = [
    'hawker_centre',
    'park',
    'museum',
    'restaurant',
    'bar',
    'cafe',
    'beach',
    'mrt_landmark',
    'library',
    'community_centre',
    'shopping_mall_common_area',
    'tourist_attraction',
  ] as const satisfies readonly VenueCategoryValue[];

  isPublic(): boolean {
    return (VenueCategory.PUBLIC_VALUES as readonly string[]).includes(this._value);
  }

  equals(other: VenueCategory): boolean {
    return this._value === other._value;
  }

  toString(): string {
    return this._value;
  }
}

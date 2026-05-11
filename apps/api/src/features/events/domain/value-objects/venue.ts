import { AppError } from '@/core/errors/app-error.js';

const ADDRESS_MIN = 1;
const ADDRESS_MAX = 300;

/**
 * Venue value object — where an Event takes place. Stores a human-readable
 * address label plus geographic coordinates. Lat/lng are validated to the
 * global range; market-specific bounding (Singapore for MVP) is enforced
 * at the use-case / API layer if needed.
 *
 * Lat/lng precision: callers pass numbers; persistence rounds to 6 decimal
 * places (~11 cm at the equator) via Postgres NUMERIC(9,6). PostGIS is a
 * deliberate non-goal for MVP — distance queries (TRI-19) can use earth_distance
 * extension or app-side calculation; a real PostGIS migration is a separate
 * issue once geospatial query volume justifies it.
 */
export class Venue {
  private constructor(
    public readonly address: string,
    public readonly latitude: number,
    public readonly longitude: number,
  ) {}

  static create(input: { address: string; latitude: number; longitude: number }): Venue {
    const address = input.address.trim();
    if (address.length < ADDRESS_MIN || address.length > ADDRESS_MAX) {
      throw AppError.validation(
        `Venue address must be ${String(ADDRESS_MIN)}-${String(ADDRESS_MAX)} characters`,
      );
    }
    if (!Number.isFinite(input.latitude) || input.latitude < -90 || input.latitude > 90) {
      throw AppError.validation('Venue latitude must be between -90 and 90');
    }
    if (!Number.isFinite(input.longitude) || input.longitude < -180 || input.longitude > 180) {
      throw AppError.validation('Venue longitude must be between -180 and 180');
    }
    return new Venue(address, input.latitude, input.longitude);
  }

  equals(other: Venue): boolean {
    return (
      this.address === other.address &&
      this.latitude === other.latitude &&
      this.longitude === other.longitude
    );
  }
}

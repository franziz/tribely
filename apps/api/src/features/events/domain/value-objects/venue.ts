import { AppError } from '@/core/errors/app-error.js';

const ADDRESS_MIN = 1;
const ADDRESS_MAX = 300;
const CITY_MIN = 1;
const CITY_MAX = 120;

/**
 * Venue value object — where an Event takes place. Stores a human-readable
 * address label, the city the venue is in, and geographic coordinates.
 *
 * `city` is a separate field from `address` (not parsed out of it) so that
 * GET /events?city=... can do an indexed equality match without parsing free
 * text. Singapore-only MVP means most rows have city='Singapore'; the index
 * earns its keep once the launch market expands.
 *
 * Lat/lng are validated to the global range; market-specific bounding
 * (Singapore for MVP) is enforced at the use-case / API layer if needed.
 * Persistence rounds to 6 decimal places (~11 cm at the equator) via Postgres
 * NUMERIC(9,6). PostGIS is a deliberate non-goal for MVP — distance queries
 * (TRI-19) can use earth_distance or app-side calculation; a real PostGIS
 * migration is a separate issue once geospatial query volume justifies it.
 */
export class Venue {
  private constructor(
    public readonly address: string,
    public readonly city: string,
    public readonly latitude: number,
    public readonly longitude: number,
  ) {}

  static create(input: {
    address: string;
    city: string;
    latitude: number;
    longitude: number;
  }): Venue {
    const address = input.address.trim();
    if (address.length < ADDRESS_MIN || address.length > ADDRESS_MAX) {
      throw AppError.validation(
        `Venue address must be ${String(ADDRESS_MIN)}-${String(ADDRESS_MAX)} characters`,
      );
    }
    const city = input.city.trim();
    if (city.length < CITY_MIN || city.length > CITY_MAX) {
      throw AppError.validation(
        `Venue city must be ${String(CITY_MIN)}-${String(CITY_MAX)} characters`,
      );
    }
    if (!Number.isFinite(input.latitude) || input.latitude < -90 || input.latitude > 90) {
      throw AppError.validation('Venue latitude must be between -90 and 90');
    }
    if (!Number.isFinite(input.longitude) || input.longitude < -180 || input.longitude > 180) {
      throw AppError.validation('Venue longitude must be between -180 and 180');
    }
    return new Venue(address, city, input.latitude, input.longitude);
  }

  equals(other: Venue): boolean {
    return (
      this.address === other.address &&
      this.city === other.city &&
      this.latitude === other.latitude &&
      this.longitude === other.longitude
    );
  }
}

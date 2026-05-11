import { AppError } from '@/core/errors/app-error.js';

export type EventCategoryValue =
  | 'drinks'
  | 'food'
  | 'hike'
  | 'museum'
  | 'sports'
  | 'nightlife'
  | 'other';

/**
 * Event category — closed enum. Stored as a plain string column in Postgres
 * (matching the codebase convention; no Prisma enum, see `revokedReason`).
 * Use `EventCategory.VALUES` to drive Zod schemas / select inputs.
 */
export class EventCategory {
  private constructor(public readonly value: EventCategoryValue) {}

  static create(raw: string): EventCategory {
    if (!EventCategory.isValid(raw)) {
      throw AppError.validation(
        `Invalid event category: ${raw} (valid: ${EventCategory.VALUES.join(', ')})`,
      );
    }
    return new EventCategory(raw);
  }

  static isValid(raw: string): raw is EventCategoryValue {
    return (EventCategory.VALUES as readonly string[]).includes(raw);
  }

  static readonly VALUES = [
    'drinks',
    'food',
    'hike',
    'museum',
    'sports',
    'nightlife',
    'other',
  ] as const satisfies readonly EventCategoryValue[];

  equals(other: EventCategory): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

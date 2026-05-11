import { AppError } from '@/core/errors/app-error.js';

const MIN = 2;
const MAX = 1000;

/**
 * Event capacity — maximum attendees including the host.
 * Constraints: integer, MIN..MAX inclusive. MIN is 2 because a tribe of one
 * is just a solo activity, not an event.
 */
export class Capacity {
  private constructor(public readonly value: number) {}

  static create(raw: number): Capacity {
    if (!Number.isInteger(raw)) {
      throw AppError.validation('Capacity must be an integer');
    }
    if (raw < MIN || raw > MAX) {
      throw AppError.validation(`Capacity must be between ${String(MIN)} and ${String(MAX)}`);
    }
    return new Capacity(raw);
  }

  static readonly MIN = MIN;
  static readonly MAX = MAX;

  equals(other: Capacity): boolean {
    return this.value === other.value;
  }
}

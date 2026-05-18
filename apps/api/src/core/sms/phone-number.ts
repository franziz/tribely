/**
 * E.164-branded phone number primitive. Lives in `core/sms/` because phone
 * numbers cross multiple bounded contexts (auth's phone verification, future
 * user profile, emergency contacts). Not tied to any one feature.
 *
 * Provisional placement: when TRI-16 lands and `User` gets a `UserPhone`
 * value object, that VO wraps this primitive (same relationship as a typed
 * `UserId` wrapping a raw CUID string).
 *
 * E.164 format: '+' followed by a country digit 1-9 then 6-14 additional
 * digits, for a total of 7-15 digits (CCNDC+subscriber). No spaces, dashes,
 * or parentheses.
 */
import { AppError } from '../errors/app-error.js';

export type E164Phone = `+${string}` & { readonly __brand: 'E164Phone' };

const E164_REGEX = /^\+[1-9]\d{6,14}$/;

export class PhoneNumber {
  private constructor(public readonly value: E164Phone) {}

  /**
   * Factory. Validates that `raw` conforms to E.164.
   *
   * Throws `AppError.validation` on failure — this is a programmer error
   * (the call site should have validated input before constructing) rather
   * than a recoverable domain failure.
   */
  static create(raw: string): PhoneNumber {
    const trimmed = raw.trim();
    if (!E164_REGEX.test(trimmed)) {
      throw AppError.validation(
        `Invalid E.164 phone number: "${trimmed}". ` +
          'Expected format: +<country-digit><6-14 digits> (e.g. +6591234567).',
      );
    }
    return new PhoneNumber(trimmed as E164Phone);
  }
}

import { AppError } from '@/core/errors/app-error.js';

/**
 * AvatarUrl value object.
 *
 * A nullable URL pointing to the user's avatar image. No upload pipeline in
 * TRI-7 — this is a plain URL column only (CEO constraint). The client is
 * responsible for providing a publicly-accessible URL.
 *
 * Validates that the value is a well-formed HTTPS URL (http is rejected to
 * prevent mixed-content warnings in mobile clients). Max 2048 chars.
 */
export class AvatarUrl {
  static readonly MAX = 2048;

  private constructor(public readonly value: string) {}

  static create(raw: string): AvatarUrl {
    const trimmed = raw.trim();
    if (trimmed.length > AvatarUrl.MAX) {
      throw AppError.validation(`Avatar URL must be at most ${String(AvatarUrl.MAX)} characters`);
    }
    let parsed: URL;
    try {
      parsed = new URL(trimmed);
    } catch {
      throw AppError.validation(`Avatar URL is not a valid URL: ${raw}`);
    }
    if (parsed.protocol !== 'https:') {
      throw AppError.validation('Avatar URL must use HTTPS');
    }
    return new AvatarUrl(trimmed);
  }

  equals(other: AvatarUrl): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

import { AppError } from '@/core/errors/app-error.js';

/**
 * Language value object.
 *
 * Represents a BCP-47-aligned language code from the platform's supported
 * picklist. Singapore-first MVP; list is deliberately constrained to the
 * languages most prevalent in the SG expat + local population.
 *
 * "yue" (Cantonese) is included despite not being an ISO 639-1 code — it
 * is the dominant Chinese variety spoken in SG alongside Mandarin.
 */
export class Language {
  /**
   * Supported language codes. Kept as a Set for O(1) lookup.
   * New entries should be added here AND to the mobile picklist (TRI-18).
   */
  static readonly VALID_CODES: ReadonlySet<string> = new Set([
    'en', // English
    'zh', // Mandarin Chinese
    'yue', // Cantonese
    'ms', // Malay
    'ta', // Tamil
    'hi', // Hindi
    'ja', // Japanese
    'ko', // Korean
    'fr', // French
    'de', // German
    'es', // Spanish
    'pt', // Portuguese
    'it', // Italian
    'nl', // Dutch
    'ru', // Russian
    'ar', // Arabic
    'th', // Thai
    'vi', // Vietnamese
    'id', // Indonesian
    'tl', // Filipino/Tagalog
  ]);

  private constructor(public readonly value: string) {}

  static create(raw: string): Language {
    const normalized = raw.trim().toLowerCase();
    if (!Language.VALID_CODES.has(normalized)) {
      throw AppError.validation(`Unsupported language code: ${raw}`);
    }
    return new Language(normalized);
  }

  equals(other: Language): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

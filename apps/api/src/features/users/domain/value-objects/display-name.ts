import { AppError } from '@/core/errors/app-error.js';

export class DisplayName {
  private constructor(public readonly value: string) {}

  static create(raw: string): DisplayName {
    const trimmed = raw.trim();
    if (trimmed.length < DisplayName.MIN || trimmed.length > DisplayName.MAX) {
      throw AppError.validation(
        `Display name must be ${DisplayName.MIN}-${DisplayName.MAX} characters`,
      );
    }
    return new DisplayName(trimmed);
  }

  equals(other: DisplayName): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }

  static readonly MIN = 2;
  static readonly MAX = 50;
}

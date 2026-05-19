import { AppError } from '@/core/errors/app-error.js';

export type SelfieStatusValue = 'pending' | 'approved' | 'rejected' | 'deleted';

/**
 * SelfieStatus value object — closed enum.
 *
 * Stored as a plain string column in Postgres (matching the codebase
 * convention; no Prisma enum). Use `SelfieStatus.VALUES` to drive Zod
 * schemas / validation.
 *
 * Identity is its normalized value — two SelfieStatuses with the same
 * value are equal. Construct via SelfieStatus.create(raw).
 */
export class SelfieStatus {
  private constructor(public readonly value: SelfieStatusValue) {}

  static create(raw: string): SelfieStatus {
    if (!SelfieStatus.isValid(raw)) {
      throw AppError.validation(
        `Invalid selfie status: "${raw}" (valid: ${SelfieStatus.VALUES.join(', ')})`,
      );
    }
    return new SelfieStatus(raw);
  }

  static isValid(raw: string): raw is SelfieStatusValue {
    return (SelfieStatus.VALUES as readonly string[]).includes(raw);
  }

  static readonly VALUES = [
    'pending',
    'approved',
    'rejected',
    'deleted',
  ] as const satisfies readonly SelfieStatusValue[];

  equals(other: SelfieStatus): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

/**
 * Opaque wrapper around a stored password hash. Constructable only from
 * a string that the PasswordHasher port has produced (or a row from
 * persistence). The string value never leaves this VO without being
 * deliberately read via `.value` — making accidental logging or
 * comparison far less likely.
 */
export class HashedPassword {
  private constructor(public readonly value: string) {}

  static fromHash(hash: string): HashedPassword {
    if (!hash) {
      throw new Error('HashedPassword cannot be empty');
    }
    return new HashedPassword(hash);
  }

  toString(): string {
    return '[HashedPassword]';
  }
}

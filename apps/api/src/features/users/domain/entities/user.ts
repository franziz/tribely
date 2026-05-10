import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { userEmailVerified } from '../events/user-email-verified.event.js';
import { userRegistered } from '../events/user-registered.event.js';
import { DisplayName } from '../value-objects/display-name.js';
import { Email } from '../value-objects/email.js';

/**
 * User aggregate root.
 *
 * Owns identity-as-known-to-the-business. Knows nothing about credentials,
 * sessions, or auth — that's the `auth` bounded context. Cross-context link
 * is by id only.
 *
 * Construction paths:
 *   - `User.register(...)` — creating a new user. Records `users.userRegistered`.
 *   - `User.rehydrate(...)` — reconstituting from persistence. No events.
 */
export class User extends AggregateRoot {
  private constructor(
    public readonly id: string,
    private _email: Email,
    private _displayName: DisplayName,
    public readonly createdAt: Date,
    private _updatedAt: Date,
    private _emailVerifiedAt: Date | null,
  ) {
    super();
  }

  static register(input: { id: string; email: Email; displayName: DisplayName; now: Date }): User {
    const user = new User(input.id, input.email, input.displayName, input.now, input.now, null);
    user.record(
      userRegistered({
        userId: user.id,
        email: user.email.value,
        displayName: user.displayName.value,
        registeredAt: input.now.toISOString(),
      }),
    );
    return user;
  }

  static rehydrate(state: {
    id: string;
    email: Email;
    displayName: DisplayName;
    createdAt: Date;
    updatedAt: Date;
    emailVerifiedAt: Date | null;
  }): User {
    return new User(
      state.id,
      state.email,
      state.displayName,
      state.createdAt,
      state.updatedAt,
      state.emailVerifiedAt,
    );
  }

  get email(): Email {
    return this._email;
  }

  get displayName(): DisplayName {
    return this._displayName;
  }

  get updatedAt(): Date {
    return this._updatedAt;
  }

  get emailVerifiedAt(): Date | null {
    return this._emailVerifiedAt;
  }

  isEmailVerified(): boolean {
    return this._emailVerifiedAt !== null;
  }

  rename(newName: DisplayName, now: Date): void {
    if (this._displayName.equals(newName)) return;
    this._displayName = newName;
    this._updatedAt = now;
    // Future event: users.userRenamed
  }

  /**
   * Marks the user's email as verified. Idempotent — calling again with an
   * already-verified user is a no-op (no event emitted) so that a duplicate
   * delivery from the transactional outbox doesn't double-publish.
   */
  verifyEmail(now: Date): void {
    if (this._emailVerifiedAt !== null) return;
    this._emailVerifiedAt = now;
    this._updatedAt = now;
    this.record(
      userEmailVerified({
        userId: this.id,
        email: this._email.value,
        verifiedAt: now.toISOString(),
      }),
    );
  }
}

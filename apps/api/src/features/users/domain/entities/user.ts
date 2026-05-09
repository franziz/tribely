import { AggregateRoot } from '@/core/domain/aggregate-root.js';
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
  ) {
    super();
  }

  static register(input: { id: string; email: Email; displayName: DisplayName; now: Date }): User {
    const user = new User(input.id, input.email, input.displayName, input.now, input.now);
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
  }): User {
    return new User(state.id, state.email, state.displayName, state.createdAt, state.updatedAt);
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

  rename(newName: DisplayName, now: Date): void {
    if (this._displayName.equals(newName)) return;
    this._displayName = newName;
    this._updatedAt = now;
    // Future event: users.userRenamed
  }
}

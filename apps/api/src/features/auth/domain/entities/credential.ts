import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { credentialIssued } from '../events/credential-issued.event.js';
import { userSignedIn } from '../events/user-signed-in.event.js';
import type { HashedPassword } from '../value-objects/hashed-password.js';

/**
 * Credential aggregate root.
 *
 * Owns the secret material used to authenticate a user. Identity is the
 * userId — there is exactly one Credential per User. Lives in the `auth`
 * bounded context, separate from the User aggregate (`users`).
 *
 * Construction paths:
 *   - `Credential.issue(...)` — first credential for a user. Records `auth.credentialIssued`.
 *   - `Credential.rehydrate(...)` — from persistence. No events.
 *
 * State changes (record events):
 *   - `markSignedIn(now)` — bumps lastSignedInAt, emits `auth.userSignedIn`.
 */
export class Credential extends AggregateRoot {
  private constructor(
    public readonly userId: string,
    private _passwordHash: HashedPassword,
    public readonly passwordSetAt: Date,
    private _lastSignedInAt: Date | null,
  ) {
    super();
  }

  static issue(input: { userId: string; passwordHash: HashedPassword; now: Date }): Credential {
    const credential = new Credential(input.userId, input.passwordHash, input.now, null);
    credential.record(
      credentialIssued({ userId: input.userId, issuedAt: input.now.toISOString() }),
    );
    return credential;
  }

  static rehydrate(state: {
    userId: string;
    passwordHash: HashedPassword;
    passwordSetAt: Date;
    lastSignedInAt: Date | null;
  }): Credential {
    return new Credential(
      state.userId,
      state.passwordHash,
      state.passwordSetAt,
      state.lastSignedInAt,
    );
  }

  get passwordHash(): HashedPassword {
    return this._passwordHash;
  }

  get lastSignedInAt(): Date | null {
    return this._lastSignedInAt;
  }

  markSignedIn(now: Date): void {
    this._lastSignedInAt = now;
    this.record(userSignedIn({ userId: this.userId, signedInAt: now.toISOString() }));
  }
}

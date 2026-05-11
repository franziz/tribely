import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { userEmailVerified } from '../events/user-email-verified.event.js';
import { userUpdated } from '../events/user-updated.event.js';
import { userRegistered } from '../events/user-registered.event.js';
import { AvatarUrl } from '../value-objects/avatar-url.js';
import { Bio } from '../value-objects/bio.js';
import { CurrentCity } from '../value-objects/current-city.js';
import { DisplayName } from '../value-objects/display-name.js';
import { Email } from '../value-objects/email.js';
import { Interest } from '../value-objects/interest.js';
import { Language } from '../value-objects/language.js';
import { TravelerType } from '../value-objects/traveler-type.js';

export interface UserProfileFields {
  bio: Bio | null;
  avatarUrl: AvatarUrl | null;
  languages: Language[];
  interests: Interest[];
  currentCity: CurrentCity | null;
  travelerType: TravelerType | null;
}

export interface UpdateProfileInput {
  bio?: string | null;
  avatarUrl?: string | null;
  languages?: string[];
  interests?: string[];
  currentCity?: string | null;
  travelerType?: string | null;
  now: Date;
}

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
 *
 * Profile mutations emit `users.userUpdated` with a full post-state snapshot
 * so consumers never need to read back the aggregate.
 */
export class User extends AggregateRoot {
  private constructor(
    public readonly id: string,
    private _email: Email,
    private _displayName: DisplayName,
    public readonly createdAt: Date,
    private _updatedAt: Date,
    private _emailVerifiedAt: Date | null,
    // Profile fields (all optional at registration, set via updateProfile)
    private _bio: Bio | null,
    private _avatarUrl: AvatarUrl | null,
    private _languages: Language[],
    private _interests: Interest[],
    private _currentCity: CurrentCity | null,
    private _travelerType: TravelerType | null,
  ) {
    super();
  }

  static register(input: { id: string; email: Email; displayName: DisplayName; now: Date }): User {
    const user = new User(
      input.id,
      input.email,
      input.displayName,
      input.now,
      input.now,
      null,
      null,
      null,
      [],
      [],
      null,
      null,
    );
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
    bio: Bio | null;
    avatarUrl: AvatarUrl | null;
    languages: Language[];
    interests: Interest[];
    currentCity: CurrentCity | null;
    travelerType: TravelerType | null;
  }): User {
    return new User(
      state.id,
      state.email,
      state.displayName,
      state.createdAt,
      state.updatedAt,
      state.emailVerifiedAt,
      state.bio,
      state.avatarUrl,
      state.languages,
      state.interests,
      state.currentCity,
      state.travelerType,
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

  get bio(): Bio | null {
    return this._bio;
  }

  get avatarUrl(): AvatarUrl | null {
    return this._avatarUrl;
  }

  get languages(): Language[] {
    return this._languages;
  }

  get interests(): Interest[] {
    return this._interests;
  }

  get currentCity(): CurrentCity | null {
    return this._currentCity;
  }

  get travelerType(): TravelerType | null {
    return this._travelerType;
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

  /**
   * Updates the user's optional profile fields. Only keys present in the
   * input are considered — absent keys leave the existing value untouched.
   * Passing `null` explicitly clears a field.
   *
   * Per-field value comparison is performed before mutating state: if the
   * supplied value is identical to the current value the field is not counted
   * as a change. Only when at least one field actually differs does the method
   * mutate state, bump `updatedAt`, and record `users.userUpdated` with a
   * full post-state snapshot.
   *
   * Validation: callers pass raw strings; this method constructs VOs and
   * throws AppError.validation on invalid values.
   */
  updateProfile(input: UpdateProfileInput): void {
    let changed = false;

    // Collect new VO values first (throws on invalid input before any mutation)
    const newBio = 'bio' in input ? (input.bio != null ? Bio.create(input.bio) : null) : undefined;
    const newAvatarUrl =
      'avatarUrl' in input
        ? input.avatarUrl != null
          ? AvatarUrl.create(input.avatarUrl)
          : null
        : undefined;
    const newLanguages =
      'languages' in input ? input.languages.map((code) => Language.create(code)) : undefined;
    const newInterests =
      'interests' in input ? input.interests.map((code) => Interest.create(code)) : undefined;
    const newCurrentCity =
      'currentCity' in input
        ? input.currentCity != null
          ? CurrentCity.create(input.currentCity)
          : null
        : undefined;
    const newTravelerType =
      'travelerType' in input
        ? input.travelerType != null
          ? TravelerType.create(input.travelerType)
          : null
        : undefined;

    // Apply with per-field value comparison
    if (newBio !== undefined) {
      const differs =
        newBio === null ? this._bio !== null : this._bio === null || !this._bio.equals(newBio);
      if (differs) {
        this._bio = newBio;
        changed = true;
      }
    }

    if (newAvatarUrl !== undefined) {
      const differs =
        newAvatarUrl === null
          ? this._avatarUrl !== null
          : this._avatarUrl === null || !this._avatarUrl.equals(newAvatarUrl);
      if (differs) {
        this._avatarUrl = newAvatarUrl;
        changed = true;
      }
    }

    if (newLanguages !== undefined) {
      const differs =
        newLanguages.length !== this._languages.length ||
        newLanguages.some(
          (l, i) => this._languages[i] === undefined || !this._languages[i].equals(l),
        );
      if (differs) {
        this._languages = newLanguages;
        changed = true;
      }
    }

    if (newInterests !== undefined) {
      const differs =
        newInterests.length !== this._interests.length ||
        newInterests.some(
          (interest, i) => this._interests[i] === undefined || !this._interests[i].equals(interest),
        );
      if (differs) {
        this._interests = newInterests;
        changed = true;
      }
    }

    if (newCurrentCity !== undefined) {
      const differs =
        newCurrentCity === null
          ? this._currentCity !== null
          : this._currentCity === null || !this._currentCity.equals(newCurrentCity);
      if (differs) {
        this._currentCity = newCurrentCity;
        changed = true;
      }
    }

    if (newTravelerType !== undefined) {
      const differs =
        newTravelerType === null
          ? this._travelerType !== null
          : this._travelerType === null || !this._travelerType.equals(newTravelerType);
      if (differs) {
        this._travelerType = newTravelerType;
        changed = true;
      }
    }

    if (!changed) return; // no-op: no keys present or all values identical

    this._updatedAt = input.now;

    // Full post-state snapshot — consumers see the complete profile, not a delta
    this.record(
      userUpdated({
        userId: this.id,
        email: this._email.value,
        displayName: this._displayName.value,
        bio: this._bio?.value ?? null,
        avatarUrl: this._avatarUrl?.value ?? null,
        languages: this._languages.map((l) => l.value),
        interests: this._interests.map((i) => i.value),
        currentCity: this._currentCity?.value ?? null,
        travelerType: this._travelerType?.value ?? null,
        emailVerifiedAt: this._emailVerifiedAt?.toISOString() ?? null,
        updatedAt: input.now.toISOString(),
      }),
    );
  }
}

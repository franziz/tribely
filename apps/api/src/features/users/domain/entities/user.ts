import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { PhoneNumber } from '@/core/sms/phone-number.js';
import { selfieAppealApproved } from '../events/selfie-appeal-approved.event.js';
import { selfieRejected } from '../events/selfie-rejected.event.js';
import { userAccountDeleted } from '../events/user-account-deleted.event.js';
import { userPhoneVerificationRevoked } from '../events/user-phone-verification-revoked.event.js';
import { userPhoneVerified } from '../events/user-phone-verified.event.js';
import { userEmailVerified } from '../events/user-email-verified.event.js';
import { userUpdated } from '../events/user-updated.event.js';
import { userRegistered } from '../events/user-registered.event.js';
import { safetyReminderShown } from '../events/safety-reminder-shown.event.js';
import { AvatarUrl } from '../value-objects/avatar-url.js';
import { Bio } from '../value-objects/bio.js';
import { CurrentCity } from '../value-objects/current-city.js';
import { DisplayName } from '../value-objects/display-name.js';
import { Email } from '../value-objects/email.js';
import { Interest } from '../value-objects/interest.js';
import { Language } from '../value-objects/language.js';
import { type SelfieFailureCategory } from '../value-objects/selfie-failure-category.js';
import { TravelerType } from '../value-objects/traveler-type.js';

/** Selfie verification status. Stored as TEXT + CHECK constraint in the DB. */
export type SelfieStatus = 'pending' | 'approved' | 'rejected';

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
    // Phone verification (null until verified via OTP)
    private _phone: PhoneNumber | null,
    private _phoneVerifiedAt: Date | null,
    // Selfie verification (TRI-70)
    private _selfieStatus: SelfieStatus | null,
    private _selfieAttemptCount: number,
    private _selfieLastFailureCategory: SelfieFailureCategory | null,
    private _selfieAppealLockedAt: Date | null,
    // TRI-134 tombstone: null until account deletion is requested + confirmed
    private _deletedAt: Date | null,
    // TRI-132 admin role: set via User.promote() for env-bootstrap promotion (TRI-156).
    private _isAdmin: boolean,
    // TRI-34 pre-event safety reminder: null until first reminder is acknowledged.
    private _safetyReminderSeenAt: Date | null,
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
      null,
      null,
      null,
      0,
      null,
      null,
      null, // deletedAt
      false, // isAdmin — new registrations are never admins
      null, // safetyReminderSeenAt — unset until first safety reminder is acknowledged
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
    phone: PhoneNumber | null;
    phoneVerifiedAt: Date | null;
    selfieStatus: SelfieStatus | null;
    selfieAttemptCount: number;
    selfieLastFailureCategory: SelfieFailureCategory | null;
    selfieAppealLockedAt: Date | null;
    deletedAt: Date | null;
    isAdmin: boolean;
    safetyReminderSeenAt: Date | null;
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
      state.phone,
      state.phoneVerifiedAt,
      state.selfieStatus,
      state.selfieAttemptCount,
      state.selfieLastFailureCategory,
      state.selfieAppealLockedAt,
      state.deletedAt,
      state.isAdmin,
      state.safetyReminderSeenAt,
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

  get phone(): PhoneNumber | null {
    return this._phone;
  }

  get phoneVerifiedAt(): Date | null {
    return this._phoneVerifiedAt;
  }

  get selfieStatus(): SelfieStatus | null {
    return this._selfieStatus;
  }

  get selfieAttemptCount(): number {
    return this._selfieAttemptCount;
  }

  get selfieLastFailureCategory(): SelfieFailureCategory | null {
    return this._selfieLastFailureCategory;
  }

  get selfieAppealLockedAt(): Date | null {
    return this._selfieAppealLockedAt;
  }

  get deletedAt(): Date | null {
    return this._deletedAt;
  }

  get isAdmin(): boolean {
    return this._isAdmin;
  }

  get safetyReminderSeenAt(): Date | null {
    return this._safetyReminderSeenAt;
  }

  /**
   * Promotes the user to admin. Idempotent at the entity level — calling on an
   * already-admin user re-sets `true` without throwing. The caller (Task B use
   * case) is responsible for skipping the persist when the user is already admin.
   *
   * No domain event is recorded: promotion observability is handled by a boot
   * WARN log + the existing http_audit chain. An event here would be YAGNI
   * (no consumer exists or is planned — TRI-156).
   *
   * @param now  Wall-clock time of promotion (injected for testability).
   */
  promote(now: Date): void {
    this._isAdmin = true;
    this._updatedAt = now;
  }

  isEmailVerified(): boolean {
    return this._emailVerifiedAt !== null;
  }

  isPhoneVerified(): boolean {
    return this._phoneVerifiedAt !== null;
  }

  /**
   * Tombstones the user account: clears all PII, replaces email with an
   * opaque placeholder, sets `deletedAt`, and records `users.userAccountDeleted`.
   *
   * The email placeholder `deleted-{cuid2}@deleted.tribely.local` preserves
   * the `users.email` UNIQUE constraint when multiple accounts are tombstoned.
   * The displayName placeholder `Deleted user {cuid2-suffix}` similarly avoids
   * any future partial-unique constraints on display names.
   *
   * Defence-in-depth invariant: throws if already tombstoned. The calling use
   * case (DeleteAccountUseCase, Brief E) checks `deletedAt !== null` first and
   * returns an appropriate error. This throw is the last-resort guard.
   *
   * Cleared fields: bio, avatarUrl, currentCity, travelerType, phone,
   * phoneVerifiedAt, emailVerifiedAt, selfieStatus, selfieLastFailureCategory,
   * selfieAppealLockedAt, selfieAttemptCount (→ 0), languages (→ []),
   * interests (→ []).
   */
  tombstone(now: Date): void {
    if (this._deletedAt !== null) {
      throw AppError.conflict('User is already tombstoned', {
        code: 'USER_ALREADY_DELETED',
        userId: this.id,
      });
    }

    const suffix = createId();
    this._email = Email.create(`deleted-${suffix}@deleted.tribely.local`);
    this._displayName = DisplayName.create(`Deleted user ${suffix.slice(0, 8)}`);
    this._bio = null;
    this._avatarUrl = null;
    this._currentCity = null;
    this._travelerType = null;
    this._phone = null;
    this._phoneVerifiedAt = null;
    this._emailVerifiedAt = null;
    this._selfieStatus = null;
    this._selfieLastFailureCategory = null;
    this._selfieAppealLockedAt = null;
    this._selfieAttemptCount = 0;
    this._languages = [];
    this._interests = [];
    this._deletedAt = now;
    this._updatedAt = now;

    this.record(
      userAccountDeleted({
        userId: this.id,
        deletedAt: now.toISOString(),
      }),
    );
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
   * Records that the pre-event safety reminder has been shown to the user for
   * a given event. Idempotent — if `_safetyReminderSeenAt` is already set,
   * returns immediately with no state change and no event, mirroring the
   * `verifyEmail` idempotency guard exactly.
   *
   * On first call: sets `_safetyReminderSeenAt = now`, bumps `_updatedAt`, and
   * records `users.safetyReminderShown` with the triggering event ID for
   * metric attribution.
   *
   * The `eventId` is injected by the caller (the aggregate does not know which
   * event triggered the reminder) and is carried in the event payload for
   * downstream metric use only.
   *
   * @param eventId  The id of the event that caused the reminder to be shown.
   * @param now      Wall-clock time of the acknowledgement.
   */
  markSafetyReminderSeen(eventId: string, now: Date): void {
    if (this._safetyReminderSeenAt !== null) return;
    this._safetyReminderSeenAt = now;
    this._updatedAt = now;
    this.record(
      safetyReminderShown({
        userId: this.id,
        eventId,
        shownAt: now.toISOString(),
      }),
    );
  }

  /**
   * Marks the user's phone number as verified. Idempotent — if the same phone
   * is already verified, this is a no-op (no events emitted). On a real change
   * (first verification or re-verification with a different number), mutates
   * state and records `users.userUpdated` + `users.userPhoneVerified`.
   */
  verifyPhone(phone: PhoneNumber, now: Date): void {
    if (this._phoneVerifiedAt !== null && this._phone?.value === phone.value) return;
    this._phone = phone;
    this._phoneVerifiedAt = now;
    this._updatedAt = now;
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
        phone: this._phone.value,
        phoneVerifiedAt: this._phoneVerifiedAt.toISOString(),
        updatedAt: now.toISOString(),
      }),
    );
    this.record(
      userPhoneVerified({
        userId: this.id,
        phoneE164: phone.value,
        verifiedAt: now.toISOString(),
      }),
    );
  }

  /**
   * Revokes phone verification when the same phone number is claimed and
   * verified by a different user (takeover scenario). Clears `_phoneVerifiedAt`
   * but RETAINS `_phone` for audit. Records `users.userUpdated` + `users.userPhoneVerificationRevoked`.
   *
   * @param newUserId   The user who is taking over ownership of this phone number.
   * @param phoneE164Hash SHA-256 hash of the phone in E.164 — hashed by the use case
   *                      via PhoneHasher before calling this method (never plaintext in events).
   * @param now         Wall-clock time of revocation.
   */
  revokePhoneVerificationOnTakeover(newUserId: string, phoneE164Hash: string, now: Date): void {
    this._phoneVerifiedAt = null;
    this._updatedAt = now;
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
        phone: this._phone?.value ?? null,
        phoneVerifiedAt: null,
        updatedAt: now.toISOString(),
      }),
    );
    this.record(
      userPhoneVerificationRevoked({
        oldUserId: this.id,
        newUserId,
        phoneE164Hash,
        revokedAt: now.toISOString(),
      }),
    );
  }

  /**
   * Records a selfie rejection. Increments `selfieAttemptCount`, sets status to
   * `rejected`, records the failure category, and — when the post-increment count
   * reaches or exceeds 3 — locks the user into the appeal path by setting
   * `selfieAppealLockedAt`.
   *
   * Emits `users.selfieRejected` with a full post-state snapshot.
   *
   * @param failureCategory  One of the four recognised rejection reasons.
   * @param now              Wall-clock time of rejection (injected for testability).
   */
  recordSelfieRejection(input: { failureCategory: SelfieFailureCategory; now: Date }): void {
    this._selfieAttemptCount += 1;
    this._selfieLastFailureCategory = input.failureCategory;
    this._selfieStatus = 'rejected';
    this._updatedAt = input.now;

    const lockedAt =
      this._selfieAttemptCount >= 3
        ? (() => {
            this._selfieAppealLockedAt = input.now;
            return input.now;
          })()
        : null;

    this.record(
      selfieRejected({
        userId: this.id,
        failureCategory: input.failureCategory,
        attemptCount: this._selfieAttemptCount,
        lockedAt: lockedAt?.toISOString() ?? null,
      }),
    );
  }

  /**
   * Records approval of a selfie appeal. Clears `selfieAppealLockedAt` and
   * resets status to `pending` so the user must re-submit a new selfie.
   *
   * Per-spec preservations:
   *   - `selfieAttemptCount` is NOT reset (historical record of prior failures).
   *   - `selfieLastFailureCategory` is NOT cleared (preserved for audit).
   *
   * Emits `users.selfieAppealApproved`.
   *
   * @param now  Wall-clock time of approval.
   */
  recordSelfieAppealApproved(input: { now: Date }): void {
    this._selfieAppealLockedAt = null;
    this._selfieStatus = 'pending';
    this._updatedAt = input.now;

    this.record(
      selfieAppealApproved({
        userId: this.id,
        clearedAt: input.now.toISOString(),
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
        phone: this._phone?.value ?? null,
        phoneVerifiedAt: this._phoneVerifiedAt?.toISOString() ?? null,
        updatedAt: input.now.toISOString(),
      }),
    );
  }
}

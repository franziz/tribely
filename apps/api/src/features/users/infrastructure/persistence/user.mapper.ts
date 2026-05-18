import type { User as UserRow } from '@prisma/client';
import { PhoneNumber } from '@/core/sms/phone-number.js';
import { User } from '../../domain/entities/user.js';
import { AvatarUrl } from '../../domain/value-objects/avatar-url.js';
import { Bio } from '../../domain/value-objects/bio.js';
import { CurrentCity } from '../../domain/value-objects/current-city.js';
import { DisplayName } from '../../domain/value-objects/display-name.js';
import { Email } from '../../domain/value-objects/email.js';
import { Interest } from '../../domain/value-objects/interest.js';
import { Language } from '../../domain/value-objects/language.js';
import { TravelerType, type TravelerTypeValue } from '../../domain/value-objects/traveler-type.js';

const VALID_TRAVELER_TYPES = new Set<TravelerTypeValue>(['local', 'traveling', 'expat']);

function isTravelerTypeValue(v: string): v is TravelerTypeValue {
  return VALID_TRAVELER_TYPES.has(v as TravelerTypeValue);
}

export const toUser = (row: UserRow): User =>
  User.rehydrate({
    id: row.id,
    email: Email.create(row.email),
    displayName: DisplayName.create(row.displayName),
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    emailVerifiedAt: row.emailVerifiedAt,
    bio: row.bio != null ? Bio.create(row.bio) : null,
    avatarUrl: row.avatarUrl != null ? AvatarUrl.create(row.avatarUrl) : null,
    languages: row.languages.map((code) => Language.create(code)),
    interests: row.interests.map((code) => Interest.create(code)),
    currentCity: row.currentCity != null ? CurrentCity.create(row.currentCity) : null,
    travelerType:
      row.travelerType != null && isTravelerTypeValue(row.travelerType)
        ? TravelerType.create(row.travelerType)
        : null,
    // Loud failure: if a persisted phone string fails E.164 validation, the data
    // integrity issue should surface immediately rather than silently drop the value.
    phone: row.phone != null ? PhoneNumber.create(row.phone) : null,
    phoneVerifiedAt: row.phoneVerifiedAt,
  });

export const toRow = (user: User): UserRow => ({
  id: user.id,
  email: user.email.value,
  displayName: user.displayName.value,
  createdAt: user.createdAt,
  updatedAt: user.updatedAt,
  emailVerifiedAt: user.emailVerifiedAt,
  bio: user.bio?.value ?? null,
  avatarUrl: user.avatarUrl?.value ?? null,
  languages: user.languages.map((l) => l.value),
  interests: user.interests.map((i) => i.value),
  currentCity: user.currentCity?.value ?? null,
  travelerType: user.travelerType?.value ?? null,
  phone: user.phone?.value ?? null,
  phoneVerifiedAt: user.phoneVerifiedAt,
});

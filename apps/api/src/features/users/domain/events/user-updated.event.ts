import type { DomainEvent } from '@/core/events/domain-event.js';

export const USER_UPDATED = 'users.userUpdated' as const;

export interface UserUpdatedPayload {
  userId: string;
  email: string;
  displayName: string;
  bio: string | null;
  avatarUrl: string | null;
  languages: string[];
  interests: string[];
  currentCity: string | null;
  travelerType: 'local' | 'traveling' | 'expat' | null;
  emailVerifiedAt: string | null;
  phone: string | null;
  phoneVerifiedAt: string | null;
  updatedAt: string;
}

export type UserUpdatedEvent = DomainEvent<UserUpdatedPayload> & {
  type: typeof USER_UPDATED;
};

export const userUpdated = (payload: UserUpdatedPayload): UserUpdatedEvent => ({
  type: USER_UPDATED,
  aggregateType: 'User',
  aggregateId: payload.userId,
  payload,
  version: 1,
});

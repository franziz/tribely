import type { DomainEvent } from '@/core/events/domain-event.js';
import type { SelfieFailureCategory } from '../value-objects/selfie-failure-category.js';

export const SELFIE_REJECTED = 'auth.selfieRejected' as const;

export interface SelfieRejectedPayload {
  userId: string;
  failureCategory: SelfieFailureCategory;
  attemptCount: number;
  /** ISO-8601 timestamp if the attempt triggered an appeal lock; null otherwise. */
  lockedAt: string | null;
}

export type SelfieRejectedEvent = DomainEvent<SelfieRejectedPayload> & {
  type: typeof SELFIE_REJECTED;
};

export const selfieRejected = (payload: SelfieRejectedPayload): SelfieRejectedEvent => ({
  type: SELFIE_REJECTED,
  aggregateType: 'User',
  aggregateId: payload.userId,
  payload,
  version: 1,
});

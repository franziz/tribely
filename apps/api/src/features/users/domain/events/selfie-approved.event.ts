import type { DomainEvent } from '@/core/events/domain-event.js';

export const SELFIE_APPROVED = 'users.selfieApproved' as const;

export interface SelfieApprovedPayload {
  userId: string;
  /** ISO-8601 timestamp — when the selfie was approved. */
  approvedAt: string;
}

export type SelfieApprovedEvent = DomainEvent<SelfieApprovedPayload> & {
  type: typeof SELFIE_APPROVED;
};

export const selfieApproved = (payload: SelfieApprovedPayload): SelfieApprovedEvent => ({
  type: SELFIE_APPROVED,
  aggregateType: 'User',
  aggregateId: payload.userId,
  payload,
  version: 1,
});

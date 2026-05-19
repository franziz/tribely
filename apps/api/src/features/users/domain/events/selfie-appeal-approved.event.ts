import type { DomainEvent } from '@/core/events/domain-event.js';

export const SELFIE_APPEAL_APPROVED = 'users.selfieAppealApproved' as const;

export interface SelfieAppealApprovedPayload {
  userId: string;
  /** ISO-8601 timestamp — when the appeal lock was cleared. */
  clearedAt: string;
}

export type SelfieAppealApprovedEvent = DomainEvent<SelfieAppealApprovedPayload> & {
  type: typeof SELFIE_APPEAL_APPROVED;
};

export const selfieAppealApproved = (
  payload: SelfieAppealApprovedPayload,
): SelfieAppealApprovedEvent => ({
  type: SELFIE_APPEAL_APPROVED,
  aggregateType: 'User',
  aggregateId: payload.userId,
  payload,
  version: 1,
});

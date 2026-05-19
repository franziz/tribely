import type { DomainEvent } from '@/core/events/domain-event.js';

export const SELFIE_DELETED = 'selfies.selfieDeleted' as const;

export interface SelfieDeletedPayload {
  selfieId: string;
  userId: string;
  reason: string;
  /** The S3 storage key that was cleared — carried so consumers can enqueue
   *  the actual object deletion without re-fetching the (now-cleared) aggregate. */
  storageKey: string | null;
  deletedAt: string; // ISO-8601
}

export type SelfieDeletedEvent = DomainEvent<SelfieDeletedPayload> & {
  type: typeof SELFIE_DELETED;
};

export const selfieDeleted = (payload: SelfieDeletedPayload): SelfieDeletedEvent => ({
  type: SELFIE_DELETED,
  aggregateType: 'Selfie',
  aggregateId: payload.selfieId,
  payload,
  version: 1,
});

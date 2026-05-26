import type { DomainEvent } from '@/core/events/domain-event.js';

export const REPORT_ESCALATED = 'reports.reportEscalated' as const;

/**
 * Emitted when a moderator escalates a Report to an external authority.
 *
 * Full post-state snapshot per project convention — diff payloads force
 * consumers to re-read the aggregate.
 */
export interface ReportEscalatedPayload {
  reportId: string;
  reporterUserId: string;
  targetType: string;
  targetId: string;
  reason: string;
  category: string;
  externalRef: string;
  escalatedByUserId: string;
  escalatedAt: string;
}

export type ReportEscalatedEvent = DomainEvent<ReportEscalatedPayload> & {
  type: typeof REPORT_ESCALATED;
};

export const reportEscalated = (payload: ReportEscalatedPayload): ReportEscalatedEvent => ({
  type: REPORT_ESCALATED,
  aggregateType: 'Report',
  aggregateId: payload.reportId,
  payload,
  version: 1,
});

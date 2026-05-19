import type { DomainEvent } from '@/core/events/domain-event.js';

export const REPORT_FILED = 'reports.reportFiled' as const;

/**
 * Emitted when a Report is first filed by a user.
 *
 * Full post-state snapshot per project convention — diff payloads force
 * consumers to re-read the aggregate.
 */
export interface ReportFiledPayload {
  reportId: string;
  reporterUserId: string;
  targetType: string;
  targetId: string;
  reason: string;
  hasComment: boolean;
  createdAt: string;
}

export type ReportFiledEvent = DomainEvent<ReportFiledPayload> & {
  type: typeof REPORT_FILED;
};

export const reportFiled = (payload: ReportFiledPayload): ReportFiledEvent => ({
  type: REPORT_FILED,
  aggregateType: 'Report',
  aggregateId: payload.reportId,
  payload,
  version: 1,
});

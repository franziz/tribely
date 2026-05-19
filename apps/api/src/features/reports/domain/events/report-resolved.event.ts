import type { DomainEvent } from '@/core/events/domain-event.js';

export const REPORT_RESOLVED = 'reports.reportResolved' as const;

/**
 * Emitted when a moderator resolves a Report (hidden or kept).
 *
 * Full post-state snapshot per project convention.
 */
export interface ReportResolvedPayload {
  reportId: string;
  reporterUserId: string;
  targetType: string;
  targetId: string;
  reason: string;
  resolution: string;
  resolvedByUserId: string;
  resolvedAt: string;
  firstReviewedAt: string | null;
}

export type ReportResolvedEvent = DomainEvent<ReportResolvedPayload> & {
  type: typeof REPORT_RESOLVED;
};

export const reportResolved = (payload: ReportResolvedPayload): ReportResolvedEvent => ({
  type: REPORT_RESOLVED,
  aggregateType: 'Report',
  aggregateId: payload.reportId,
  payload,
  version: 1,
});

import type { Report as ReportRow, Prisma } from '@prisma/client';
import { Report } from '../../domain/entities/report.js';
import type { EscalationCategory } from '../../domain/entities/report.js';
import { ReportComment } from '../../domain/value-objects/report-comment.js';
import { ReportReason } from '../../domain/value-objects/report-reason.js';
import { ReportTarget } from '../../domain/value-objects/report-target.js';

/**
 * Reconstruct a Report aggregate from a Prisma row.
 *
 * `externalInputCount` defaults to 0 for list paths that don't invoke
 * resolve() and therefore don't need the escalation-resolve guard.
 * `ReportPrismaRepository.findById` passes the real count (fetched from
 * `ModerationActionAuditRepository.countExternalInputs`) for single-record
 * loads where resolve() may be called.
 */
export const toReport = (row: ReportRow, externalInputCount = 0): Report =>
  Report.rehydrate({
    id: row.id,
    reporterUserId: row.reporterUserId,
    target: ReportTarget.create(row.targetType, row.targetId),
    reason: ReportReason.create(row.reason),
    comment: row.comment !== null ? ReportComment.create(row.comment) : null,
    createdAt: row.createdAt,
    firstReviewedAt: row.firstReviewedAt,
    resolvedAt: row.resolvedAt,
    resolution: row.resolution,
    resolvedByUserId: row.resolvedByUserId,
    escalatedAt: row.escalatedAt,
    escalationCategory: row.escalationCategory as EscalationCategory | null,
    externalRef: row.externalRef,
    escalatedByUserId: row.escalatedByUserId,
    externalInputCount,
  });

/**
 * Project a Report aggregate to a Prisma create input.
 */
export const toRow = (report: Report): Prisma.ReportUncheckedCreateInput => ({
  id: report.id,
  reporterUserId: report.reporterUserId,
  targetType: report.target.type,
  targetId: report.target.id,
  reason: report.reason.value,
  comment: report.comment?.value ?? null,
  createdAt: report.createdAt,
  firstReviewedAt: report.firstReviewedAt,
  resolvedAt: report.resolvedAt,
  resolution: report.resolution,
  resolvedByUserId: report.resolvedByUserId,
  escalatedAt: report.escalatedAt,
  escalationCategory: report.escalationCategory,
  externalRef: report.externalRef,
  escalatedByUserId: report.escalatedByUserId,
});

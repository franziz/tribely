import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { ModerationAction, ModerationTargetType } from '../types/moderation-action.js';

export type { ModerationAction, ModerationTargetType };

export interface ModerationActionAuditRecord {
  id: string;
  operatorUserId: string;
  action: ModerationAction;
  /** Nullable: Cat 4 cancel_event_for_safety may have no upstream report row (TRI-193). */
  reportId: string | null;
  targetType: ModerationTargetType;
  targetId: string;
  reason: string | null;
  contentSnapshot: string | null;
  /** Nullable: no reporter when there is no upstream report (TRI-193). */
  reporterUserId: string | null;
  /** Machine-readable safety code, e.g. 'safety'. Null for non-Cat-4 actions. */
  reasonCode: string | null;
  /** Operator free-text narrative for cancel_event_for_safety (≤500 chars). Null for other actions. */
  justificationText: string | null;
  /** Nullable link to a moderation_reports row. Used by TRI-141 sweep severance join. */
  originatingReportId: string | null;
  actedAt: Date;
  requestId: string | null;
  recordedAt: Date;
}

/**
 * Append-only by contract for evidence fields (operatorUserId, action, reason,
 * contentSnapshot, etc. — never UPDATEable). The ONLY mutation method is
 * `severOriginatingReportId`, a PDPA s25 cross-reference minimisation operation
 * triggered by the 12-month report-retention sweep (runbook §5). No other
 * UPDATE / DELETE / repair / backfill path exists.
 */
export interface ModerationActionAuditRepository {
  record(entry: ModerationActionAuditRecord, ctx: TxContext): Promise<void>;

  /**
   * Severs the cross-reference from audit rows to a purged moderation_reports
   * row by NULLing originatingReportId. Triggered by the 12-month report-
   * retention sweep (runbook §5).
   *
   * Returns the number of audit rows updated.
   *
   * PDPA s25 minimisation operation — the SOLE permitted mutation on this
   * otherwise-append-only table. All other UPDATE/DELETE paths remain
   * forbidden by design.
   *
   * Required `ctx`: the severance MUST commit atomically with the
   * moderation_reports row deletion that triggered it (TRI-198 AC: no partial sever).
   */
  severOriginatingReportId(reportId: string, ctx: TxContext): Promise<number>;
}

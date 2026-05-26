import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  EscalationCategory,
  ExternalInputSource,
  ModerationAction,
  ModerationTargetType,
} from '../types/moderation-action.js';

export type { EscalationCategory, ExternalInputSource, ModerationAction, ModerationTargetType };

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
  /**
   * Populated when action='escalate' or action='resolve_with_override'.
   * Carried forward on resolve_with_override for end-to-end traceability.
   */
  escalationCategory: EscalationCategory | null;
  /** Operator-supplied external reference (ticket ID, case number, etc.). Populated when action='escalate'. */
  externalRef: string | null;
  /** Source of an external input. Populated when action='record_external_input'. */
  externalSource: ExternalInputSource | null;
  /** Free-text disposition from external party (≤500 chars). Populated when action='record_external_input'. */
  externalDisposition: string | null;
  /**
   * Operator-supplied ISO8601 timestamp for when the external input was received.
   * Distinct from actedAt (operator's CLI invocation clock). Both are required for PDPC inspection.
   * Populated when action='record_external_input'.
   */
  externalReceivedAt: Date | null;
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

  /**
   * Count of `record_external_input` audit rows for a given report.
   * Read-only — consumed by ReportPrismaRepository.findById to hydrate
   * Report.externalInputCount for the resolve-guard rule (AC5).
   *
   * This is the ONLY public read on this otherwise-write-only repository.
   * Justification: the count is a derived property of the report aggregate
   * but its source-of-truth lives in audit (append-only event-log shape).
   * Per CLAUDE.md A11 application-ports rule, a sibling-feature read accessor
   * on the audit repository is the bounded-context-correct surface — NOT
   * a denormalized count column on `reports`.
   */
  countExternalInputs(reportId: string, ctx?: TxContext): Promise<number>;
}

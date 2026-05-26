import { createId } from '@paralleldrive/cuid2';
import { getRequestContext } from '@/core/context/request-context.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  EscalationCategory,
  ExternalInputSource,
  ModerationAction,
  ModerationTargetType,
} from '../../domain/types/moderation-action.js';
import type {
  ModerationActionAuditRecord,
  ModerationActionAuditRepository,
} from '../../domain/repositories/moderation-action-audit.repository.js';

export interface RecordModerationActionInput {
  /**
   * Optional caller-supplied ID. When provided (e.g. CancelEventForSafetyUseCase
   * needs to return the auditRowId before the transaction commits), the supplied
   * value is used as the record's PK; otherwise a fresh cuid2 is generated here.
   */
  id?: string;
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
  escalationCategory?: EscalationCategory | null;
  /** Operator-supplied external reference (ticket ID, case number, etc.). Populated when action='escalate'. */
  externalRef?: string | null;
  /** Source of an external input. Populated when action='record_external_input'. */
  externalSource?: ExternalInputSource | null;
  /** Free-text disposition from external party (≤500 chars). Populated when action='record_external_input'. */
  externalDisposition?: string | null;
  /**
   * Operator-supplied ISO8601 timestamp for when the external input was received.
   * Distinct from actedAt (operator's CLI invocation clock). Both required for PDPC inspection.
   * Populated when action='record_external_input'.
   */
  externalReceivedAt?: Date | null;
  actedAt: Date;
}

/**
 * Records one moderation action to the append-only audit table.
 *
 * Atomicity contract: caller MUST be inside its own `unitOfWork.run` and
 * pass the supplied TxContext. The audit row commits atomically with the
 * triggering report state transition (and any cascaded review hide).
 *
 * `requestId` is read from AsyncLocalStorage. CLI callers wrap in
 * `runAsSystem('cli.moderation.<verb>', fn)` producing a
 * `system:cli.moderation.<verb>:<cuid>` synthetic requestId; this is the
 * channel-attribution signal for PDPC inspection.
 *
 * NO read methods on the public surface (auditor access is out-of-band
 * SQL). NO update / repair / backfill methods (PDPA s24 contract).
 */
export class RecordModerationActionUseCase {
  constructor(private readonly repository: ModerationActionAuditRepository) {}

  async execute(input: RecordModerationActionInput, ctx: TxContext): Promise<void> {
    const requestId = getRequestContext()?.requestId ?? null;
    const record: ModerationActionAuditRecord = {
      id: input.id ?? createId(),
      operatorUserId: input.operatorUserId,
      action: input.action,
      reportId: input.reportId,
      targetType: input.targetType,
      targetId: input.targetId,
      reason: input.reason,
      contentSnapshot: input.contentSnapshot,
      reporterUserId: input.reporterUserId,
      reasonCode: input.reasonCode,
      justificationText: input.justificationText,
      originatingReportId: input.originatingReportId,
      escalationCategory: input.escalationCategory ?? null,
      externalRef: input.externalRef ?? null,
      externalSource: input.externalSource ?? null,
      externalDisposition: input.externalDisposition ?? null,
      externalReceivedAt: input.externalReceivedAt ?? null,
      actedAt: input.actedAt,
      requestId,
      recordedAt: new Date(),
    };
    await this.repository.record(record, ctx);
  }
}

import { createId } from '@paralleldrive/cuid2';
import { getRequestContext } from '@/core/context/request-context.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  ModerationAction,
  ModerationTargetType,
} from '../../domain/types/moderation-action.js';
import type {
  ModerationActionAuditRecord,
  ModerationActionAuditRepository,
} from '../../domain/repositories/moderation-action-audit.repository.js';

export interface RecordModerationActionInput {
  operatorUserId: string;
  action: ModerationAction;
  reportId: string;
  targetType: ModerationTargetType;
  targetId: string;
  reason: string | null;
  contentSnapshot: string | null;
  reporterUserId: string;
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
      id: createId(),
      operatorUserId: input.operatorUserId,
      action: input.action,
      reportId: input.reportId,
      targetType: input.targetType,
      targetId: input.targetId,
      reason: input.reason,
      contentSnapshot: input.contentSnapshot,
      reporterUserId: input.reporterUserId,
      actedAt: input.actedAt,
      requestId,
      recordedAt: new Date(),
    };
    await this.repository.record(record, ctx);
  }
}

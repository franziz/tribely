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
 * Append-only by contract. PDPA s24 evidence integrity requires no UPDATE /
 * repair / backfill path. Mirrors SelfieDeletionEventRepository — required
 * TxContext, single `record(...)` method.
 */
export interface ModerationActionAuditRepository {
  record(entry: ModerationActionAuditRecord, ctx: TxContext): Promise<void>;
}

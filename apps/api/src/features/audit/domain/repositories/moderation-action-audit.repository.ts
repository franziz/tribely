import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { ModerationAction, ModerationTargetType } from '../types/moderation-action.js';

export type { ModerationAction, ModerationTargetType };

export interface ModerationActionAuditRecord {
  id: string;
  operatorUserId: string;
  action: ModerationAction;
  reportId: string;
  targetType: ModerationTargetType;
  targetId: string;
  reason: string | null;
  contentSnapshot: string | null;
  reporterUserId: string;
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

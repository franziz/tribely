import type { TxContext } from '@/core/db/unit-of-work.port.js';

export type EventAuditPhase = 'published' | 'dispatched' | 'failed' | 'blocked';

export interface EventAuditLogRecord {
  id: string;
  requestId: string | null;
  eventSeq: bigint;
  eventType: string;
  /** null = "published" (producer-side); non-null = consumer-side phase */
  consumerName: string | null;
  phase: EventAuditPhase;
  attempt: number | null;
  errorMessage: string | null;
  recordedAt: Date;
}

export interface EventAuditLogRepository {
  /**
   * Record one or more event-audit rows. Accepts an optional TxContext so
   * publish-side audit rows can be written inside the same Prisma tx as the
   * outbox row (atomicity); dispatch-side audit rows pass undefined and run
   * in their own transaction.
   */
  record(entries: EventAuditLogRecord[], ctx?: TxContext): Promise<void>;
}

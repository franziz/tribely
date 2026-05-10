import { createId } from '@paralleldrive/cuid2';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  EventAuditLogRecord,
  EventAuditLogRepository,
} from '../../domain/repositories/event-audit-log.repository.js';

export interface PublishedEventInput {
  requestId: string | null;
  eventSeq: bigint;
  eventType: string;
}

/**
 * Records the producer-side audit row for one or more events that were just
 * written to the outbox. Called from `OutboxEventPublisher` *inside the same
 * transaction* as the outbox row — the audit row commits or rolls back
 * together with the event. Atomicity matters here: an audit row that
 * references a non-existent outbox seq would corrupt the audit chain.
 */
export class RecordEventPublishedUseCase {
  constructor(private readonly repository: EventAuditLogRepository) {}

  async execute(events: PublishedEventInput[], ctx: TxContext): Promise<void> {
    if (events.length === 0) return;
    const now = new Date();
    const records: EventAuditLogRecord[] = events.map((e) => ({
      id: createId(),
      requestId: e.requestId,
      eventSeq: e.eventSeq,
      eventType: e.eventType,
      consumerName: null, // null distinguishes "published" rows
      phase: 'published',
      attempt: null,
      errorMessage: null,
      recordedAt: now,
    }));
    await this.repository.record(records, ctx);
  }
}

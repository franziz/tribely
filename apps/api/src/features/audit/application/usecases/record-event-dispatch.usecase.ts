import { createId } from '@paralleldrive/cuid2';
import type {
  EventAuditLogRecord,
  EventAuditLogRepository,
  EventAuditPhase,
} from '../../domain/repositories/event-audit-log.repository.js';

export interface DispatchOutcomeInput {
  requestId: string | null;
  eventSeq: bigint;
  eventType: string;
  consumerName: string;
  phase: Exclude<EventAuditPhase, 'published'>;
  attempt: number;
  errorMessage: string | null;
}

/**
 * Records the consumer-side audit row for one event/consumer pair. Called
 * by `OutboxDispatcher` after the handler returns or throws. Runs in its
 * own transaction (not chained to the consumer's work) — the dispatcher
 * already committed the consumer-offset update; the audit is informational.
 */
export class RecordEventDispatchUseCase {
  constructor(private readonly repository: EventAuditLogRepository) {}

  async execute(input: DispatchOutcomeInput): Promise<void> {
    const record: EventAuditLogRecord = {
      id: createId(),
      requestId: input.requestId,
      eventSeq: input.eventSeq,
      eventType: input.eventType,
      consumerName: input.consumerName,
      phase: input.phase,
      attempt: input.attempt,
      errorMessage: input.errorMessage,
      recordedAt: new Date(),
    };
    await this.repository.record([record]);
  }
}

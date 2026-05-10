import { getRequestContext } from '../context/request-context.js';
import { unwrapTx } from '../db/prisma-unit-of-work.js';
import type { TxContext } from '../db/unit-of-work.port.js';
import { logger } from '../middleware/logger.js';
import type { DomainEvent } from './domain-event.js';
import type { EventPublisher } from './event-publisher.port.js';

export interface PublishAuditHook {
  /**
   * Called inside the same transaction as the outbox row write, with the
   * (now-assigned) seq + requestId + eventType for each event published.
   * Implementation persists `event_audit_logs` rows. Atomic with the
   * outbox row — partial-publish corruption is impossible.
   */
  onPublished(
    events: Array<{
      requestId: string | null;
      eventSeq: bigint;
      eventType: string;
    }>,
    ctx: TxContext,
  ): Promise<void>;
}

const NOOP_AUDIT_HOOK: PublishAuditHook = {
  onPublished: () => Promise.resolve(),
};

/**
 * Production EventPublisher impl. Writes events to the `outbox_events`
 * table inside the supplied TxContext, so event persistence is atomic with
 * the data change that produced it. The OutboxDispatcher polls the table
 * and forwards events to registered consumers.
 *
 * Audit correlation:
 *   - Reads the AsyncLocalStorage frame for `requestId` + `actorUserId`,
 *     persists both onto each outbox row.
 *   - Calls the audit hook with the assigned `seq` so an
 *     `event_audit_logs` row commits atomically with the outbox row.
 *
 * If `getRequestContext()` returns null we log WARN and persist nulls.
 * That signals a publish path not wrapped in a context frame — almost
 * certainly a bug (boot code that forgot `runAsSystem`, a test that didn't
 * mock the middleware).
 */
export class OutboxEventPublisher implements EventPublisher {
  private auditHook: PublishAuditHook = NOOP_AUDIT_HOOK;

  /**
   * Wire the audit hook. Called once from buildContainer after the audit
   * feature is constructed. Decoupled this way so the events core has no
   * compile-time dependency on the audit feature.
   */
  setAuditHook(hook: PublishAuditHook): void {
    this.auditHook = hook;
  }

  async publish(ctx: TxContext, ...events: DomainEvent[]): Promise<void> {
    if (events.length === 0) return;
    const requestContext = getRequestContext();
    if (!requestContext) {
      logger.warn(
        { eventCount: events.length, eventTypes: events.map((e) => e.type) },
        'OutboxEventPublisher.publish called outside a request context — wrap callers in runWithContext or runAsSystem',
      );
    }
    const requestId = requestContext?.requestId ?? null;
    const actorUserId = requestContext?.actorUserId ?? null;

    const tx = unwrapTx(ctx);

    // We use `create` per event (not `createMany`) so we get back the
    // auto-generated `seq` for the audit hook. The events are inside the
    // same transaction either way; per-row inserts are negligibly slower
    // for the typical 1–4-event publish in MVP traffic.
    const audit: Array<{
      requestId: string | null;
      eventSeq: bigint;
      eventType: string;
    }> = [];
    for (const event of events) {
      const created = await tx.outboxEvent.create({
        data: {
          type: event.type,
          aggregateType: event.aggregateType,
          aggregateId: event.aggregateId,
          payload: event.payload as object,
          requestId,
          actorUserId,
        },
        select: { seq: true },
      });
      audit.push({
        requestId,
        eventSeq: created.seq,
        eventType: event.type,
      });
    }

    await this.auditHook.onPublished(audit, ctx);
  }
}

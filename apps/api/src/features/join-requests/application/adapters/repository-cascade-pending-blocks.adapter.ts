import { unwrapTx } from '@/core/db/prisma-unit-of-work.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import { joinRequestCancelledBySystem } from '../../domain/events/cancelled-by-system.event.js';
import type { CascadePendingBlocksPort } from '../ports/cascade-pending-blocks.port.js';

/**
 * Concrete implementation of `CascadePendingBlocksPort`.
 *
 * Bulk-cancels pending/approved future join requests between the two parties
 * (in EITHER direction) when a block is placed.
 *
 * "Future" means the parent event ends AFTER the current time — we don't
 * cancel requests for events that have already ended because the interaction
 * already occurred.
 *
 * For each cancelled row this adapter publishes a
 * `joinRequests.cancelledBySystem` event so downstream consumers can react
 * (e.g., send notifications, update headcounts).
 */
export class RepositoryCascadePendingBlocksAdapter implements CascadePendingBlocksPort {
  constructor(private readonly publisher: EventPublisher) {}

  async cancelPendingAndFutureAcceptedBetween(
    input: { userA: string; userB: string },
    ctx: TxContext,
  ): Promise<{ cancelledCount: number }> {
    const client = unwrapTx(ctx);
    const now = new Date();

    // Find all active (pending | approved) join requests between the two users
    // for future events (endsAt > now), in EITHER direction.
    const targetRows = await client.joinRequest.findMany({
      where: {
        status: { in: ['pending', 'approved'] },
        OR: [
          { requesterUserId: input.userA, event: { hostUserId: input.userB, endsAt: { gt: now } } },
          { requesterUserId: input.userB, event: { hostUserId: input.userA, endsAt: { gt: now } } },
        ],
      },
      select: {
        id: true,
        eventId: true,
        requesterUserId: true,
        event: { select: { hostUserId: true } },
      },
    });

    if (targetRows.length === 0) {
      return { cancelledCount: 0 };
    }

    const ids = targetRows.map((r) => r.id);

    await client.joinRequest.updateMany({
      where: { id: { in: ids } },
      data: {
        status: 'cancelled',
        decisionReason: 'blocked',
        decidedAt: now,
      },
    });

    // Publish one cancelledBySystem event per cancelled join request.
    const events = targetRows.map((row) =>
      joinRequestCancelledBySystem({
        joinRequestId: row.id,
        eventId: row.eventId,
        requesterUserId: row.requesterUserId,
        hostUserId: row.event.hostUserId,
        reason: 'blocked',
        occurredAt: now.toISOString(),
      }),
    );

    // Assign synthetic aggregate IDs — each row IS an aggregate but we're
    // publishing events outside the aggregate's own lifecycle here (bulk path).
    // The aggregateId is already set from joinRequestId in the factory above.
    await this.publisher.publish(ctx, ...events);

    return { cancelledCount: targetRows.length };
  }
}

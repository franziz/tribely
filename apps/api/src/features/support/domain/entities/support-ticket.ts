import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { ticketSubmitted } from '../events/ticket-submitted.event.js';
import type { SupportCategory } from '../value-objects/support-category.js';
import type { SupportMessage } from '../value-objects/support-message.js';
import type { ReportIdReference } from '../value-objects/report-id-reference.js';

/**
 * SupportTicket aggregate root.
 *
 * Represents a user-submitted in-app support request. Captures the category,
 * message body, and an optional free-text reference to a moderation report
 * (NOT a FK — legal-compliance guardrail prevents joining to moderation_reports).
 *
 * Construction paths:
 *   - `SupportTicket.create(...)` — new instance. Records `support.ticketSubmitted`.
 *     Caller (use case) is responsible for computing `userEmailHash` (SHA-256 of the
 *     lowercase-trimmed email) before calling `create` — keeps crypto out of the domain.
 *   - `SupportTicket.rehydrate(...)` — reconstituting from persistence. No events.
 */
export class SupportTicket extends AggregateRoot {
  private constructor(
    public readonly id: string,
    public readonly userId: string | null,
    public readonly userEmailSnapshot: string | null,
    public readonly category: SupportCategory,
    public readonly message: SupportMessage,
    public readonly reportId: string | null,
    public readonly status: string,
    public readonly createdAt: Date,
    public readonly resolvedAt: Date | null,
  ) {
    super();
  }

  static create(input: {
    id: string;
    userId: string;
    userEmailSnapshot: string;
    /** SHA-256 hex of the lowercase-trimmed email. Computed by the use case. */
    userEmailHash: string;
    category: SupportCategory;
    message: SupportMessage;
    reportId?: ReportIdReference;
    now: Date;
  }): SupportTicket {
    const instance = new SupportTicket(
      input.id,
      input.userId,
      input.userEmailSnapshot,
      input.category,
      input.message,
      input.reportId?.value ?? null,
      'open',
      input.now,
      null,
    );

    instance.record(
      ticketSubmitted({
        ticketId: input.id,
        userId: input.userId,
        userEmailHash: input.userEmailHash,
        category: input.category.value,
        hasReportId: input.reportId !== undefined,
        occurredAt: input.now.toISOString(),
      }),
    );

    return instance;
  }

  static rehydrate(state: {
    id: string;
    userId: string | null;
    userEmailSnapshot: string | null;
    category: SupportCategory;
    message: SupportMessage;
    reportId: string | null;
    status: string;
    createdAt: Date;
    resolvedAt: Date | null;
  }): SupportTicket {
    return new SupportTicket(
      state.id,
      state.userId,
      state.userEmailSnapshot,
      state.category,
      state.message,
      state.reportId,
      state.status,
      state.createdAt,
      state.resolvedAt,
    );
  }
}

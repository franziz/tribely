import type { DomainEvent } from '@/core/events/domain-event.js';

export const TICKET_SUBMITTED = 'support.ticketSubmitted' as const;

export interface TicketSubmittedEventPayload {
  ticketId: string;
  userId: string;
  /** SHA-256 of the lowercase-trimmed email. Mirrors TRI-16 hash-PII-in-long-lived-events precedent. */
  userEmailHash: string;
  category: string;
  /** True when a reportId was supplied; the reportId value itself is NOT included. */
  hasReportId: boolean;
  occurredAt: string;
}

export type TicketSubmittedEvent = DomainEvent<TicketSubmittedEventPayload> & {
  type: typeof TICKET_SUBMITTED;
};

export const ticketSubmitted = (payload: TicketSubmittedEventPayload): TicketSubmittedEvent => ({
  type: TICKET_SUBMITTED,
  aggregateType: 'SupportTicket',
  aggregateId: payload.ticketId,
  payload,
  version: 1,
});

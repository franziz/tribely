/**
 * A DomainEvent records a fact about something that happened in the domain.
 * Aggregates push events onto an internal buffer when their state changes;
 * application services pull them off and publish via the EventPublisher port.
 *
 * Naming: `<feature>.<verbPastTense>` — past tense because an event is a record
 * of something that has already happened.
 */
export interface DomainEvent<TPayload = unknown> {
  readonly type: string;
  readonly aggregateType: string;
  readonly aggregateId: string;
  readonly payload: TPayload;
  readonly version: number;
}

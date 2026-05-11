import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { AppError } from '@/core/errors/app-error.js';
import { eventCancelled } from '../events/event-cancelled.event.js';
import { eventCompleted } from '../events/event-completed.event.js';
import { eventCreated } from '../events/event-created.event.js';
import { eventPublished } from '../events/event-published.event.js';
import type { Capacity } from '../value-objects/capacity.js';
import type { EventCategory } from '../value-objects/event-category.js';
import type { Venue } from '../value-objects/venue.js';

export type EventStatus = 'draft' | 'published' | 'cancelled' | 'completed';
export type CostSplit = 'own' | 'host_paid' | 'split';
export type ApprovalMode = 'auto' | 'manual';

const TITLE_MIN = 3;
const TITLE_MAX = 120;
const DESCRIPTION_MAX = 2000;
const CANCELLATION_REASON_MAX = 500;

/**
 * Event aggregate root — the core "thing happening" travelers gather around.
 *
 * Lifecycle: `draft → published → (cancelled | completed)`. `cancel` is also
 * reachable from `draft`. All transitions are:
 *   - strict (throw `AppError.conflict` on invalid source state), AND
 *   - idempotent on the same target state (no-op + no event recorded),
 *     mirroring `RefreshToken.revoke`.
 *
 * Construction:
 *   - `Event.create(...)` — new draft. Records `events.eventCreated` with a
 *     rich snapshot so downstream projections don't need an extra lookup.
 *   - `Event.rehydrate(...)` — from persistence. No events.
 *
 * Invariants enforced in `create`:
 *   - title 3-120 chars (trimmed; empty rejected)
 *   - description ≤ 2000 chars (optional; empty → null)
 *   - endsAt > startsAt
 *   - startsAt > now (clock-injected; tests stay deterministic)
 */
export class Event extends AggregateRoot {
  private constructor(
    public readonly id: string,
    public readonly hostUserId: string,
    private _title: string,
    private _description: string | null,
    private _venue: Venue,
    private _startsAt: Date,
    private _endsAt: Date,
    private _capacity: Capacity,
    private _category: EventCategory,
    private _costSplit: CostSplit,
    private _approvalMode: ApprovalMode,
    private _status: EventStatus,
    private _cancellationReason: string | null,
    public readonly createdAt: Date,
    private _updatedAt: Date,
  ) {
    super();
  }

  static create(input: {
    id: string;
    hostUserId: string;
    title: string;
    description: string | null;
    venue: Venue;
    startsAt: Date;
    endsAt: Date;
    capacity: Capacity;
    category: EventCategory;
    costSplit: CostSplit;
    approvalMode: ApprovalMode;
    now: Date;
  }): Event {
    const title = input.title.trim();
    if (title.length < TITLE_MIN || title.length > TITLE_MAX) {
      throw AppError.validation(
        `Event title must be ${String(TITLE_MIN)}-${String(TITLE_MAX)} characters`,
      );
    }
    const description = normalizeDescription(input.description);
    if (description !== null && description.length > DESCRIPTION_MAX) {
      throw AppError.validation(
        `Event description must be at most ${String(DESCRIPTION_MAX)} characters`,
      );
    }
    if (input.endsAt.getTime() <= input.startsAt.getTime()) {
      throw AppError.validation('Event endsAt must be after startsAt');
    }
    if (input.startsAt.getTime() <= input.now.getTime()) {
      throw AppError.validation('Event startsAt must be in the future');
    }

    const event = new Event(
      input.id,
      input.hostUserId,
      title,
      description,
      input.venue,
      input.startsAt,
      input.endsAt,
      input.capacity,
      input.category,
      input.costSplit,
      input.approvalMode,
      'draft',
      null,
      input.now,
      input.now,
    );
    event.record(
      eventCreated({
        eventId: input.id,
        hostUserId: input.hostUserId,
        title,
        description,
        venue: {
          address: input.venue.address,
          latitude: input.venue.latitude,
          longitude: input.venue.longitude,
        },
        startsAt: input.startsAt.toISOString(),
        endsAt: input.endsAt.toISOString(),
        capacity: input.capacity.value,
        category: input.category.value,
        costSplit: input.costSplit,
        approvalMode: input.approvalMode,
        createdAt: input.now.toISOString(),
      }),
    );
    return event;
  }

  static rehydrate(state: {
    id: string;
    hostUserId: string;
    title: string;
    description: string | null;
    venue: Venue;
    startsAt: Date;
    endsAt: Date;
    capacity: Capacity;
    category: EventCategory;
    costSplit: CostSplit;
    approvalMode: ApprovalMode;
    status: EventStatus;
    cancellationReason: string | null;
    createdAt: Date;
    updatedAt: Date;
  }): Event {
    return new Event(
      state.id,
      state.hostUserId,
      state.title,
      state.description,
      state.venue,
      state.startsAt,
      state.endsAt,
      state.capacity,
      state.category,
      state.costSplit,
      state.approvalMode,
      state.status,
      state.cancellationReason,
      state.createdAt,
      state.updatedAt,
    );
  }

  get title(): string {
    return this._title;
  }
  get description(): string | null {
    return this._description;
  }
  get venue(): Venue {
    return this._venue;
  }
  get startsAt(): Date {
    return this._startsAt;
  }
  get endsAt(): Date {
    return this._endsAt;
  }
  get capacity(): Capacity {
    return this._capacity;
  }
  get category(): EventCategory {
    return this._category;
  }
  get costSplit(): CostSplit {
    return this._costSplit;
  }
  get approvalMode(): ApprovalMode {
    return this._approvalMode;
  }
  get status(): EventStatus {
    return this._status;
  }
  get cancellationReason(): string | null {
    return this._cancellationReason;
  }
  get updatedAt(): Date {
    return this._updatedAt;
  }

  publish(now: Date): void {
    if (this._status === 'published') return; // idempotent
    if (this._status !== 'draft') {
      throw AppError.conflict(`Cannot publish event in status: ${this._status}`);
    }
    this._status = 'published';
    this._updatedAt = now;
    this.record(
      eventPublished({
        eventId: this.id,
        hostUserId: this.hostUserId,
        publishedAt: now.toISOString(),
      }),
    );
  }

  cancel(reason: string, now: Date): void {
    const trimmed = reason.trim();
    if (trimmed.length === 0) {
      throw AppError.validation('Cancellation reason is required');
    }
    if (trimmed.length > CANCELLATION_REASON_MAX) {
      throw AppError.validation(
        `Cancellation reason must be at most ${String(CANCELLATION_REASON_MAX)} characters`,
      );
    }
    if (this._status === 'cancelled') return; // idempotent
    if (this._status === 'completed') {
      throw AppError.conflict('Cannot cancel a completed event');
    }
    this._status = 'cancelled';
    this._cancellationReason = trimmed;
    this._updatedAt = now;
    this.record(
      eventCancelled({
        eventId: this.id,
        hostUserId: this.hostUserId,
        reason: trimmed,
        cancelledAt: now.toISOString(),
      }),
    );
  }

  markCompleted(now: Date): void {
    if (this._status === 'completed') return; // idempotent
    if (this._status !== 'published') {
      throw AppError.conflict(`Cannot complete event in status: ${this._status}`);
    }
    this._status = 'completed';
    this._updatedAt = now;
    this.record(
      eventCompleted({
        eventId: this.id,
        hostUserId: this.hostUserId,
        completedAt: now.toISOString(),
      }),
    );
  }
}

const normalizeDescription = (raw: string | null): string | null => {
  if (raw === null) return null;
  const trimmed = raw.trim();
  return trimmed.length === 0 ? null : trimmed;
};

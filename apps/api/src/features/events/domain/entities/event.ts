import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { AppError } from '@/core/errors/app-error.js';
import { eventCancelled } from '../events/event-cancelled.event.js';
import { eventCompleted } from '../events/event-completed.event.js';
import { eventCreated } from '../events/event-created.event.js';
import { eventPublished } from '../events/event-published.event.js';
import { eventUpdated } from '../events/event-updated.event.js';
import type { Capacity } from '../value-objects/capacity.js';
import type { EventCategory } from '../value-objects/event-category.js';
import type { VenueCategory } from '../value-objects/venue-category.js';
import type { Venue } from '../value-objects/venue.js';

export type EventStatus = 'draft' | 'published' | 'cancelled' | 'completed';
export type ApprovalMode = 'auto' | 'manual';

const TITLE_MIN = 3;
const TITLE_MAX = 120;
const DESCRIPTION_MAX = 2000;
const COST_NOTES_MAX = 200;
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
 *   - costNotes ≤ 200 chars (optional; empty/whitespace → null)
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
    private _venueCategory: VenueCategory,
    private _costNotes: string | null,
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
    venueCategory: VenueCategory;
    costNotes?: string | null;
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
    const costNotes = normalizeCostNotes(input.costNotes ?? null);
    if (costNotes !== null && costNotes.length > COST_NOTES_MAX) {
      throw AppError.validation(
        `Event costNotes must be at most ${String(COST_NOTES_MAX)} characters`,
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
      input.venueCategory,
      costNotes,
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
          city: input.venue.city,
          latitude: input.venue.latitude,
          longitude: input.venue.longitude,
        },
        startsAt: input.startsAt.toISOString(),
        endsAt: input.endsAt.toISOString(),
        capacity: input.capacity.value,
        category: input.category.value,
        venueCategory: input.venueCategory.value,
        costNotes,
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
    venueCategory: VenueCategory;
    costNotes: string | null;
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
      state.venueCategory,
      state.costNotes,
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
  get venueCategory(): VenueCategory {
    return this._venueCategory;
  }
  get costNotes(): string | null {
    return this._costNotes;
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

  /**
   * Apply a partial edit. Allowed only while the event is `draft` or
   * `published` — cancelled / completed events are terminal and immutable.
   * Validates the post-edit state against the same invariants as `create`
   * (titles/descriptions in range, endsAt > startsAt, startsAt > now).
   *
   * No-op if no field actually changes (don't bump `updatedAt`, don't emit
   * `events.eventUpdated`). Records one `events.eventUpdated` event with a
   * full post-edit snapshot otherwise.
   */
  edit(
    patch: {
      title?: string;
      description?: string | null;
      venue?: Venue;
      startsAt?: Date;
      endsAt?: Date;
      capacity?: Capacity;
      category?: EventCategory;
      venueCategory?: VenueCategory;
      costNotes?: string | null;
      approvalMode?: ApprovalMode;
    },
    now: Date,
  ): void {
    if (this._status !== 'draft' && this._status !== 'published') {
      throw AppError.conflict(`Cannot edit event in status: ${this._status}`);
    }

    const nextTitle = patch.title !== undefined ? patch.title.trim() : this._title;
    if (nextTitle.length < TITLE_MIN || nextTitle.length > TITLE_MAX) {
      throw AppError.validation(
        `Event title must be ${String(TITLE_MIN)}-${String(TITLE_MAX)} characters`,
      );
    }
    const nextDescription =
      patch.description !== undefined ? normalizeDescription(patch.description) : this._description;
    if (nextDescription !== null && nextDescription.length > DESCRIPTION_MAX) {
      throw AppError.validation(
        `Event description must be at most ${String(DESCRIPTION_MAX)} characters`,
      );
    }
    const nextCostNotes =
      patch.costNotes !== undefined ? normalizeCostNotes(patch.costNotes) : this._costNotes;
    if (nextCostNotes !== null && nextCostNotes.length > COST_NOTES_MAX) {
      throw AppError.validation(
        `Event costNotes must be at most ${String(COST_NOTES_MAX)} characters`,
      );
    }
    const nextVenue = patch.venue ?? this._venue;
    const nextStartsAt = patch.startsAt ?? this._startsAt;
    const nextEndsAt = patch.endsAt ?? this._endsAt;
    if (nextEndsAt.getTime() <= nextStartsAt.getTime()) {
      throw AppError.validation('Event endsAt must be after startsAt');
    }
    if (nextStartsAt.getTime() <= now.getTime()) {
      throw AppError.validation('Event startsAt must be in the future');
    }
    const nextCapacity = patch.capacity ?? this._capacity;
    const nextCategory = patch.category ?? this._category;
    const nextVenueCategory = patch.venueCategory ?? this._venueCategory;
    const nextApprovalMode = patch.approvalMode ?? this._approvalMode;

    const unchanged =
      nextTitle === this._title &&
      nextDescription === this._description &&
      nextCostNotes === this._costNotes &&
      nextVenue.equals(this._venue) &&
      nextStartsAt.getTime() === this._startsAt.getTime() &&
      nextEndsAt.getTime() === this._endsAt.getTime() &&
      nextCapacity.equals(this._capacity) &&
      nextCategory.equals(this._category) &&
      nextVenueCategory.equals(this._venueCategory) &&
      nextApprovalMode === this._approvalMode;
    if (unchanged) return;

    this._title = nextTitle;
    this._description = nextDescription;
    this._costNotes = nextCostNotes;
    this._venue = nextVenue;
    this._startsAt = nextStartsAt;
    this._endsAt = nextEndsAt;
    this._capacity = nextCapacity;
    this._category = nextCategory;
    this._venueCategory = nextVenueCategory;
    this._approvalMode = nextApprovalMode;
    this._updatedAt = now;

    this.record(
      eventUpdated({
        eventId: this.id,
        hostUserId: this.hostUserId,
        title: this._title,
        description: this._description,
        venue: {
          address: this._venue.address,
          city: this._venue.city,
          latitude: this._venue.latitude,
          longitude: this._venue.longitude,
        },
        startsAt: this._startsAt.toISOString(),
        endsAt: this._endsAt.toISOString(),
        capacity: this._capacity.value,
        category: this._category.value,
        venueCategory: this._venueCategory.value,
        costNotes: this._costNotes,
        approvalMode: this._approvalMode,
        updatedAt: now.toISOString(),
      }),
    );
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

const normalizeCostNotes = (raw: string | null): string | null => {
  if (raw === null) return null;
  const trimmed = raw.trim();
  return trimmed.length === 0 ? null : trimmed;
};

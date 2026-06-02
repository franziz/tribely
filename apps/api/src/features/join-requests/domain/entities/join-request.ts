import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { AppError } from '@/core/errors/app-error.js';
import { joinRequestApproved } from '../events/approved.event.js';
import { joinRequestCancelledByRequester } from '../events/cancelled-by-requester.event.js';
import { joinRequestRejected } from '../events/rejected.event.js';
import { joinRequestRemovedByHost } from '../events/removed-by-host.event.js';
import { joinRequestRequested } from '../events/requested.event.js';

export type JoinRequestStatus = 'pending' | 'approved' | 'rejected' | 'cancelled' | 'removed_by_host';

const REJECTION_REASON_MAX = 500;
const REMOVE_REASON_MAX = 200;

/**
 * Snapshot of the parent Event taken at request time. Embedded in `request()`
 * (for `requested` payload) and again at `approve()` time (for `approved`
 * payload). Passing it in keeps the aggregate ignorant of cross-aggregate
 * reads — the use case looks up the event and hands the snapshot here.
 */
export interface JoinRequestEventSnapshot {
  startsAt: Date;
  endsAt: Date;
  venue: {
    address: string;
    city: string;
    latitude: number;
    longitude: number;
  };
  hostUserId: string;
}

/**
 * JoinRequest aggregate root — a single user's request to join an event.
 *
 * Lifecycle: `pending → (approved | rejected | cancelled)`.
 *
 * Idempotency contract — DELIBERATELY different from `Event.cancel`:
 *   - Same-state transitions throw `AppError.conflict` with a structured
 *     `details: { subcode: 'ALREADY_APPROVED' | 'ALREADY_REJECTED' |
 *     'ALREADY_CANCELLED' }`. NOT silent no-ops.
 *   - Rationale: a host clicking "approve" twice is a UX surface that needs
 *     to know the real outcome (was it already approved by my co-host? did
 *     my first click race a sibling request that took the last seat?). The
 *     subcode lets the presentation layer render the right user-facing
 *     message without inspecting the message string.
 *   - This protects the audit chain: every state transition produces exactly
 *     one event, never two; never zero with the caller believing it succeeded.
 *
 * Capacity: this aggregate does NOT know about event capacity. The use case
 * acquires SELECT FOR UPDATE on the parent Event row, counts approved siblings,
 * and compares against `capacity - 1` (capacity includes the host) BEFORE
 * calling `approve()`. Keeps cross-aggregate concerns out of the entity.
 *
 * Auto-approve: `request({ autoApprove: true })` immediately calls
 * `approve()` internally, so both `requested` AND `approved` events are
 * recorded on the same aggregate before `pullEvents()` is called. The
 * capacity check in the use case still runs first.
 */
export class JoinRequest extends AggregateRoot {
  private constructor(
    public readonly id: string,
    public readonly eventId: string,
    public readonly requesterUserId: string,
    public readonly requestedAt: Date,
    private _status: JoinRequestStatus,
    private _decidedAt: Date | null,
    private _decidedByUserId: string | null,
    private _decisionReason: string | null,
  ) {
    super();
  }

  static request(input: {
    id: string;
    eventId: string;
    requesterUserId: string;
    now: Date;
    autoApprove: boolean;
    hostUserId: string;
    eventSnapshot: JoinRequestEventSnapshot;
  }): JoinRequest {
    const jr = new JoinRequest(
      input.id,
      input.eventId,
      input.requesterUserId,
      input.now,
      'pending',
      null,
      null,
      null,
    );
    jr.record(
      joinRequestRequested({
        id: input.id,
        eventId: input.eventId,
        requesterUserId: input.requesterUserId,
        requestedAt: input.now.toISOString(),
        eventStartsAt: input.eventSnapshot.startsAt.toISOString(),
        eventEndsAt: input.eventSnapshot.endsAt.toISOString(),
      }),
    );
    if (input.autoApprove) {
      jr.approve({
        by: input.hostUserId,
        now: input.now,
        eventSnapshot: input.eventSnapshot,
      });
    }
    return jr;
  }

  static rehydrate(state: {
    id: string;
    eventId: string;
    requesterUserId: string;
    requestedAt: Date;
    status: JoinRequestStatus;
    decidedAt: Date | null;
    decidedByUserId: string | null;
    decisionReason: string | null;
  }): JoinRequest {
    return new JoinRequest(
      state.id,
      state.eventId,
      state.requesterUserId,
      state.requestedAt,
      state.status,
      state.decidedAt,
      state.decidedByUserId,
      state.decisionReason,
    );
  }

  get status(): JoinRequestStatus {
    return this._status;
  }
  get decidedAt(): Date | null {
    return this._decidedAt;
  }
  get decidedByUserId(): string | null {
    return this._decidedByUserId;
  }
  get decisionReason(): string | null {
    return this._decisionReason;
  }

  /**
   * Approve the request (host action; or implicit in auto-approve flow).
   * `by` MUST be the host's user id — even in the auto-approve case the
   * decision is attributed to the host (never null), preserving "who approved
   * this?" answerability in the audit trail.
   */
  approve(input: { by: string; now: Date; eventSnapshot: JoinRequestEventSnapshot }): void {
    if (this._status === 'approved') {
      throw AppError.conflict('Join request is already approved', { subcode: 'ALREADY_APPROVED' });
    }
    if (this._status !== 'pending') {
      throw AppError.conflict(`Cannot approve from status: ${this._status}`);
    }
    this._status = 'approved';
    this._decidedAt = input.now;
    this._decidedByUserId = input.by;
    this._decisionReason = null;
    this.record(
      joinRequestApproved({
        id: this.id,
        eventId: this.eventId,
        requesterUserId: this.requesterUserId,
        approvedByUserId: input.by,
        approvedAt: input.now.toISOString(),
        hostUserId: input.eventSnapshot.hostUserId,
        eventStartsAt: input.eventSnapshot.startsAt.toISOString(),
        eventEndsAt: input.eventSnapshot.endsAt.toISOString(),
        eventVenue: {
          address: input.eventSnapshot.venue.address,
          city: input.eventSnapshot.venue.city,
          latitude: input.eventSnapshot.venue.latitude,
          longitude: input.eventSnapshot.venue.longitude,
        },
      }),
    );
  }

  /**
   * Reject the request (host action). Reason is REQUIRED — the audit chain
   * and the requester-facing UX both demand a human-readable cause.
   */
  reject(input: { by: string; reason: string; now: Date }): void {
    const trimmed = input.reason.trim();
    if (trimmed.length === 0) {
      throw AppError.validation('Rejection reason is required');
    }
    if (trimmed.length > REJECTION_REASON_MAX) {
      throw AppError.validation(
        `Rejection reason must be at most ${String(REJECTION_REASON_MAX)} characters`,
      );
    }
    if (this._status === 'rejected') {
      throw AppError.conflict('Join request is already rejected', { subcode: 'ALREADY_REJECTED' });
    }
    if (this._status !== 'pending') {
      throw AppError.conflict(`Cannot reject from status: ${this._status}`);
    }
    this._status = 'rejected';
    this._decidedAt = input.now;
    this._decidedByUserId = input.by;
    this._decisionReason = trimmed;
    this.record(
      joinRequestRejected({
        id: this.id,
        eventId: this.eventId,
        requesterUserId: this.requesterUserId,
        rejectedByUserId: input.by,
        reason: trimmed,
        rejectedAt: input.now.toISOString(),
      }),
    );
  }

  /**
   * Remove an approved attendee (host action). Only valid from `approved` —
   * the host can only remove someone who has already been let in. Reason is
   * REQUIRED (1-200 chars; the cap is tighter than rejection per CEO Condition
   * B — keep REMOVE_REASON_MAX and REJECTION_REASON_MAX separate). Both
   * `removedByUserId` and `hostUserId` are carried in the event for symmetry
   * with `joinRequestApproved` and future Path C (admin-remove) optionality.
   */
  removeByHost(input: {
    by: string;
    reason: string;
    now: Date;
    hostUserId: string;
  }): void {
    const trimmed = input.reason.trim();
    if (trimmed.length === 0) {
      throw AppError.validation('Removal reason is required');
    }
    if (trimmed.length > REMOVE_REASON_MAX) {
      throw AppError.validation(
        `Removal reason must be at most ${String(REMOVE_REASON_MAX)} characters`,
      );
    }
    if (this._status === 'removed_by_host') {
      throw AppError.conflict('Join request was already removed by host', {
        subcode: 'ALREADY_REMOVED_BY_HOST',
      });
    }
    if (this._status !== 'approved') {
      throw AppError.conflict(`Cannot remove from status: ${this._status}`);
    }
    this._status = 'removed_by_host';
    this._decidedAt = input.now;
    this._decidedByUserId = input.by;
    this._decisionReason = trimmed;
    this.record(
      joinRequestRemovedByHost({
        id: this.id,
        eventId: this.eventId,
        requesterUserId: this.requesterUserId,
        removedByUserId: input.by,
        hostUserId: input.hostUserId,
        reason: trimmed,
        removedAt: input.now.toISOString(),
      }),
    );
  }

  /**
   * Cancel by the requester. Allowed from BOTH `pending` AND `approved` —
   * "I changed my mind about going" is a real flow even after approval.
   * Not allowed from `rejected` (the host already decided no) or
   * `cancelled` (would be a no-op masquerading as success — see class
   * docstring on the idempotency contract).
   *
   * `decidedByUserId` is left null — the requester's id is already on the
   * row as `requesterUserId`, so duplicating it would be redundant. The
   * `previousStatus` is captured in the event payload so consumers can
   * distinguish "withdrew before host decided" from "dropped out after
   * approval" (which the host needs to know about for headcount).
   */
  cancelByRequester(now: Date): void {
    if (this._status === 'cancelled') {
      throw AppError.conflict('Join request is already cancelled', {
        subcode: 'ALREADY_CANCELLED',
      });
    }
    if (this._status === 'rejected') {
      throw AppError.conflict('Cannot cancel a rejected join request');
    }
    const previousStatus = this._status; // 'pending' | 'approved'
    this._status = 'cancelled';
    this._decidedAt = now;
    this._decidedByUserId = null;
    this._decisionReason = null;
    this.record(
      joinRequestCancelledByRequester({
        id: this.id,
        eventId: this.eventId,
        requesterUserId: this.requesterUserId,
        previousStatus,
        cancelledAt: now.toISOString(),
      }),
    );
  }
}

import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { AppError } from '@/core/errors/app-error.js';
import { checkInAcknowledged } from '../events/check-in-acknowledged.event.js';
import { checkInCreated } from '../events/check-in-created.event.js';
import { checkInFlagged } from '../events/check-in-flagged.event.js';

export type CheckInStatus = 'pending' | 'ok' | 'flagged';

const REPORT_BODY_MAX = 2000;

/**
 * PostEventCheckIn aggregate root.
 *
 * Tracks a single attendee's post-event check-in for an event. Created
 * automatically after an event ends for every approved attendee; the attendee
 * either acknowledges (ok) or flags (flagged) with a report body. Hosts see
 * flagged check-ins for review.
 *
 * Construction paths:
 *   - `PostEventCheckIn.create(...)` — new check-in. Records `check-ins.checkInCreated`.
 *   - `PostEventCheckIn.rehydrate(...)` — reconstituting from persistence. No events.
 *
 * State transitions:
 *   - `acknowledge({ now })` — pending → ok. Records `check-ins.checkInAcknowledged`.
 *   - `flag({ reportBody, now })` — pending → flagged. Records `check-ins.checkInFlagged`.
 */
export class PostEventCheckIn extends AggregateRoot {
  private constructor(
    public readonly id: string,
    public readonly userId: string,
    public readonly eventId: string,
    public readonly hostUserId: string,
    private _status: CheckInStatus,
    public readonly createdAt: Date,
    private _acknowledgedAt: Date | null,
    private _flaggedAt: Date | null,
    private _reportBody: string | null,
    private _resolvedAt: Date | null,
  ) {
    super();
  }

  static create(input: {
    id: string;
    userId: string;
    eventId: string;
    hostUserId: string;
    now: Date;
  }): PostEventCheckIn {
    const instance = new PostEventCheckIn(
      input.id,
      input.userId,
      input.eventId,
      input.hostUserId,
      'pending',
      input.now,
      null,
      null,
      null,
      null,
    );
    instance.record(
      checkInCreated({
        checkInId: input.id,
        userId: input.userId,
        eventId: input.eventId,
        hostUserId: input.hostUserId,
        createdAt: input.now.toISOString(),
      }),
    );
    return instance;
  }

  static rehydrate(state: {
    id: string;
    userId: string;
    eventId: string;
    hostUserId: string;
    status: CheckInStatus;
    createdAt: Date;
    acknowledgedAt: Date | null;
    flaggedAt: Date | null;
    reportBody: string | null;
    resolvedAt: Date | null;
  }): PostEventCheckIn {
    return new PostEventCheckIn(
      state.id,
      state.userId,
      state.eventId,
      state.hostUserId,
      state.status,
      state.createdAt,
      state.acknowledgedAt,
      state.flaggedAt,
      state.reportBody,
      state.resolvedAt,
    );
  }

  get status(): CheckInStatus {
    return this._status;
  }

  get acknowledgedAt(): Date | null {
    return this._acknowledgedAt;
  }

  get flaggedAt(): Date | null {
    return this._flaggedAt;
  }

  get reportBody(): string | null {
    return this._reportBody;
  }

  get resolvedAt(): Date | null {
    return this._resolvedAt;
  }

  /**
   * Transition pending → ok. Throws CONFLICT if the check-in is not pending.
   */
  acknowledge(input: { now: Date }): void {
    if (this._status !== 'pending') {
      throw AppError.conflict(`Cannot acknowledge check-in in status: ${this._status}`);
    }
    this._status = 'ok';
    this._acknowledgedAt = input.now;
    this.record(
      checkInAcknowledged({
        checkInId: this.id,
        userId: this.userId,
        eventId: this.eventId,
        acknowledgedAt: input.now.toISOString(),
      }),
    );
  }

  /**
   * Transition pending → flagged. Throws UNPROCESSABLE on empty or overlong
   * reportBody. Throws CONFLICT if the check-in is not pending.
   */
  flag(input: { reportBody: string; now: Date }): void {
    const trimmed = input.reportBody.trim();
    if (trimmed.length === 0) {
      throw AppError.unprocessable('Report body must not be empty', {
        subcode: 'REPORT_EMPTY',
      });
    }
    if (trimmed.length > REPORT_BODY_MAX) {
      throw AppError.unprocessable(
        `Report body must be at most ${String(REPORT_BODY_MAX)} characters`,
        { subcode: 'REPORT_TOO_LONG' },
      );
    }
    if (this._status !== 'pending') {
      throw AppError.conflict(`Cannot flag check-in in status: ${this._status}`);
    }
    this._status = 'flagged';
    this._flaggedAt = input.now;
    this._reportBody = trimmed;
    this.record(
      checkInFlagged({
        checkInId: this.id,
        userId: this.userId,
        eventId: this.eventId,
        hostUserId: this.hostUserId,
        flaggedAt: input.now.toISOString(),
        reportBody: trimmed,
      }),
    );
  }
}

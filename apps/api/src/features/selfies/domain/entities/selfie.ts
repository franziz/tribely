import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { AppError } from '@/core/errors/app-error.js';
import { selfieDeleted } from '../events/selfie-deleted.event.js';
import type { SelfieStatusValue } from '../value-objects/selfie-status.js';

/**
 * Selfie aggregate root.
 *
 * Represents a user's selfie submitted for identity verification.
 * Tracks its lifecycle status and manages PDPA-compliant deletion.
 *
 * Construction paths:
 *   - `Selfie.create(...)` — new submission from the intake flow (TRI-23).
 *     Sets status to `pending`. No events recorded (YAGNI — pending row in
 *     admin queue is the observable record).
 *   - `Selfie.rehydrate(...)` — reconstituting from persistence. No events.
 *
 * State transitions:
 *   - `approve(now)` — `pending → approved`. Sets `approvedAt`.
 *   - `markDeleted(now, reason)` — any non-deleted → `deleted`, clears
 *     `storageKey`, sets `deletedAt`, records `selfies.selfieDeleted`.
 *
 * Deletion semantics:
 *   - Calling `markDeleted` on an already-deleted aggregate throws a
 *     conflict error (defense-in-depth on top of the SQL eligibility filter).
 *   - Cascade applies regardless of source status: `pending`, `approved`,
 *     and `rejected` are all valid pre-deletion states (AC #6).
 */
export class Selfie extends AggregateRoot {
  private constructor(
    public readonly id: string,
    public readonly userId: string,
    private _status: SelfieStatusValue,
    private _storageKey: string | null,
    private _approvedAt: Date | null,
    private _rejectedAt: Date | null,
    private _deletedAt: Date | null,
    public readonly createdAt: Date,
    private _updatedAt: Date,
  ) {
    super();
  }

  /**
   * Create a new Selfie aggregate for a just-uploaded submission.
   *
   * Sets status to `pending`, all decision timestamps to null, and
   * `createdAt`/`updatedAt` to `now`. No domain event is recorded on
   * creation — the pending row surfacing in the admin queue is the
   * observable record (YAGNI: no `selfieSubmitted` event per EL brief).
   *
   * @param id         Use-case-generated cuid2 — the domain owns identity.
   * @param userId     The authenticated user submitting the selfie.
   * @param storageKey The S3 object key from the presign step.
   * @param now        Wall-clock time of submission (injected for testability).
   */
  static create(input: { id: string; userId: string; storageKey: string; now: Date }): Selfie {
    return new Selfie(
      input.id,
      input.userId,
      'pending',
      input.storageKey,
      null, // approvedAt
      null, // rejectedAt
      null, // deletedAt
      input.now,
      input.now,
    );
  }

  /**
   * Transition this selfie to `approved` status.
   *
   * Sets `approvedAt` to `now`. Valid source state: `pending`.
   * Throws `AppError.conflict` if already approved or deleted.
   *
   * Used by ApproveSelfieUseCase (TRI-23 Brief B).
   */
  approve(now: Date): void {
    if (this._status === 'approved') {
      throw AppError.conflict(`Selfie ${this.id} is already approved`);
    }
    if (this._status === 'deleted') {
      throw AppError.conflict(`Selfie ${this.id} is deleted and cannot be approved`);
    }

    this._status = 'approved';
    this._approvedAt = now;
    this._updatedAt = now;
  }

  static rehydrate(state: {
    id: string;
    userId: string;
    status: SelfieStatusValue;
    storageKey: string | null;
    approvedAt: Date | null;
    rejectedAt: Date | null;
    deletedAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
  }): Selfie {
    return new Selfie(
      state.id,
      state.userId,
      state.status,
      state.storageKey,
      state.approvedAt,
      state.rejectedAt,
      state.deletedAt,
      state.createdAt,
      state.updatedAt,
    );
  }

  get status(): SelfieStatusValue {
    return this._status;
  }

  get storageKey(): string | null {
    return this._storageKey;
  }

  get approvedAt(): Date | null {
    return this._approvedAt;
  }

  get rejectedAt(): Date | null {
    return this._rejectedAt;
  }

  get deletedAt(): Date | null {
    return this._deletedAt;
  }

  get updatedAt(): Date {
    return this._updatedAt;
  }

  /**
   * Transition this selfie to `deleted` status.
   *
   * - Clears `storageKey` to null (object reference cleared; actual S3
   *   deletion is handled by the PendingStorageDeleteRepository queue).
   * - Sets `deletedAt` to `now`.
   * - Records a `selfies.selfieDeleted` domain event.
   * - Throws `AppError.conflict` if the selfie is already deleted
   *   (defense-in-depth; SQL eligibility filter is the primary guard).
   *
   * Valid source states: `pending`, `approved`, `rejected` (AC #6 —
   * deletion cascades regardless of status).
   */
  markDeleted(now: Date, reason: string): void {
    if (this._status === 'deleted') {
      throw AppError.conflict(`Selfie ${this.id} is already deleted`);
    }

    const previousStorageKey = this._storageKey;

    this._status = 'deleted';
    this._storageKey = null;
    this._deletedAt = now;
    this._updatedAt = now;

    this.record(
      selfieDeleted({
        selfieId: this.id,
        userId: this.userId,
        reason,
        storageKey: previousStorageKey,
        deletedAt: now.toISOString(),
      }),
    );
  }
}

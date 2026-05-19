import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { AppError } from '@/core/errors/app-error.js';
import { reportFiled } from '../events/report-filed.event.js';
import { reportResolved } from '../events/report-resolved.event.js';
import type { ReportComment } from '../value-objects/report-comment.js';
import type { ReportReason } from '../value-objects/report-reason.js';
import type { ReportTarget } from '../value-objects/report-target.js';

/**
 * Report aggregate root — a user-filed content-moderation report targeting
 * another entity (initially only 'review', with 'user' and 'event' stubs
 * for future implementation).
 *
 * Lifecycle:
 *   - `Report.file(...)` — new report. Records `reports.reportFiled`.
 *   - `report.touch(now)` — first review by a moderator. Sets
 *     `firstReviewedAt` if not already set. Idempotent — subsequent calls
 *     are no-ops and do NOT record any event.
 *   - `report.resolve(...)` — final moderation decision. Sets `resolvedAt`,
 *     `resolution`, and `resolvedByUserId`. Records `reports.reportResolved`.
 *     Throws `ReportAlreadyResolved` if already resolved (append-only invariant
 *     for legal compliance).
 *
 * `touch()` is intentionally event-free — it is an internal moderation state
 * that has no downstream consumer significance at MVP. If future tooling needs
 * to react to first-review, add a `reports.reportTouched` event here.
 */
export class Report extends AggregateRoot {
  private constructor(
    public readonly id: string,
    public readonly reporterUserId: string,
    public readonly target: ReportTarget,
    public readonly reason: ReportReason,
    public readonly comment: ReportComment | null,
    public readonly createdAt: Date,
    private _firstReviewedAt: Date | null,
    private _resolvedAt: Date | null,
    private _resolution: string | null,
    private _resolvedByUserId: string | null,
  ) {
    super();
  }

  // ---- Factories ----

  static file(input: {
    id: string;
    reporterUserId: string;
    target: ReportTarget;
    reason: ReportReason;
    comment: ReportComment | null;
    now: Date;
  }): Report {
    const report = new Report(
      input.id,
      input.reporterUserId,
      input.target,
      input.reason,
      input.comment,
      input.now,
      null,
      null,
      null,
      null,
    );
    report.record(
      reportFiled({
        reportId: input.id,
        reporterUserId: input.reporterUserId,
        targetType: input.target.type,
        targetId: input.target.id,
        reason: input.reason.value,
        hasComment: input.comment !== null,
        createdAt: input.now.toISOString(),
      }),
    );
    return report;
  }

  static rehydrate(state: {
    id: string;
    reporterUserId: string;
    target: ReportTarget;
    reason: ReportReason;
    comment: ReportComment | null;
    createdAt: Date;
    firstReviewedAt: Date | null;
    resolvedAt: Date | null;
    resolution: string | null;
    resolvedByUserId: string | null;
  }): Report {
    return new Report(
      state.id,
      state.reporterUserId,
      state.target,
      state.reason,
      state.comment,
      state.createdAt,
      state.firstReviewedAt,
      state.resolvedAt,
      state.resolution,
      state.resolvedByUserId,
    );
  }

  // ---- Getters ----

  get firstReviewedAt(): Date | null {
    return this._firstReviewedAt;
  }

  get resolvedAt(): Date | null {
    return this._resolvedAt;
  }

  get resolution(): string | null {
    return this._resolution;
  }

  get resolvedByUserId(): string | null {
    return this._resolvedByUserId;
  }

  get isResolved(): boolean {
    return this._resolvedAt !== null;
  }

  // ---- Commands ----

  /**
   * Mark the report as first-reviewed by a moderator.
   *
   * Sets `firstReviewedAt` only if it has never been set. Subsequent calls
   * are a no-op — no field mutation, no event emitted.
   */
  touch(now: Date): void {
    if (this._firstReviewedAt !== null) return;
    this._firstReviewedAt = now;
  }

  /**
   * Record the final moderation decision on this report.
   *
   * Throws `AppError.conflict('reports.reportAlreadyResolved', ...)` if the
   * report has already been resolved — append-only invariant enforced by the
   * domain for legal compliance.
   *
   * Records `reports.reportResolved`.
   */
  resolve(input: { resolution: 'hidden' | 'kept'; resolvedByUserId: string; now: Date }): void {
    if (this._resolvedAt !== null) {
      throw AppError.conflict('Report has already been resolved', {
        subcode: 'reports.reportAlreadyResolved',
      });
    }

    this._resolvedAt = input.now;
    this._resolution = input.resolution;
    this._resolvedByUserId = input.resolvedByUserId;

    this.record(
      reportResolved({
        reportId: this.id,
        reporterUserId: this.reporterUserId,
        targetType: this.target.type,
        targetId: this.target.id,
        reason: this.reason.value,
        resolution: input.resolution,
        resolvedByUserId: input.resolvedByUserId,
        resolvedAt: input.now.toISOString(),
        firstReviewedAt: this._firstReviewedAt?.toISOString() ?? null,
      }),
    );
  }
}

import { AggregateRoot } from '@/core/domain/aggregate-root.js';
import { AppError } from '@/core/errors/app-error.js';
import { reportEscalated } from '../events/report-escalated.event.js';
import { reportFiled } from '../events/report-filed.event.js';
import { reportResolved } from '../events/report-resolved.event.js';
import type { ReportComment } from '../value-objects/report-comment.js';
import type { ReportReason } from '../value-objects/report-reason.js';
import type { ReportTarget } from '../value-objects/report-target.js';

export type EscalationCategory =
  | 'criminal-content'
  | 'imminent-harm'
  | 'ambiguous-policy'
  | 'external-jurisdiction';

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
 *   - `report.escalate(...)` — escalate to an external authority. Sets
 *     `escalatedAt`, `escalationCategory`, `externalRef`, `escalatedByUserId`.
 *     Records `reports.reportEscalated`. Append-only invariant: throws if
 *     already escalated or already resolved.
 *   - `report.resolve(...)` — final moderation decision. Sets `resolvedAt`,
 *     `resolution`, and `resolvedByUserId`. Records `reports.reportResolved`.
 *     Throws `ReportAlreadyResolved` if already resolved (append-only invariant
 *     for legal compliance). When the report is escalated, requires either an
 *     external-input row (`externalInputCount > 0`) or an `overrideReason`;
 *     certain categories (`criminal-content`, `imminent-harm`) prohibit overrides.
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
    private _escalatedAt: Date | null,
    private _escalationCategory: EscalationCategory | null,
    private _externalRef: string | null,
    private _escalatedByUserId: string | null,
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
    escalatedAt?: Date | null;
    escalationCategory?: EscalationCategory | null;
    externalRef?: string | null;
    escalatedByUserId?: string | null;
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
      state.escalatedAt ?? null,
      state.escalationCategory ?? null,
      state.externalRef ?? null,
      state.escalatedByUserId ?? null,
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

  get escalatedAt(): Date | null {
    return this._escalatedAt;
  }

  get escalationCategory(): EscalationCategory | null {
    return this._escalationCategory;
  }

  get externalRef(): string | null {
    return this._externalRef;
  }

  get escalatedByUserId(): string | null {
    return this._escalatedByUserId;
  }

  get isEscalated(): boolean {
    return this._escalatedAt !== null;
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
   * Escalate the report to an external authority (law enforcement, platform
   * safety team, etc.).
   *
   * Append-only invariant: throws if the report is already resolved or already
   * escalated (no re-escalation by PM non-goal). Records `reports.reportEscalated`.
   */
  escalate(input: {
    category: EscalationCategory;
    externalRef: string;
    escalatedByUserId: string;
    now: Date;
  }): void {
    if (this._resolvedAt !== null) {
      throw AppError.conflict('Report has already been resolved', {
        subcode: 'reports.reportAlreadyResolved',
      });
    }
    if (this._escalatedAt !== null) {
      throw AppError.conflict('Report is already escalated', {
        subcode: 'reports.reportAlreadyEscalated',
      });
    }
    if (input.externalRef.trim().length === 0) {
      throw AppError.validation('External reference required', {
        subcode: 'reports.externalRefRequired',
      });
    }

    this._escalatedAt = input.now;
    this._escalationCategory = input.category;
    this._externalRef = input.externalRef;
    this._escalatedByUserId = input.escalatedByUserId;

    this.record(
      reportEscalated({
        reportId: this.id,
        reporterUserId: this.reporterUserId,
        targetType: this.target.type,
        targetId: this.target.id,
        reason: this.reason.value,
        category: input.category,
        externalRef: input.externalRef,
        escalatedByUserId: input.escalatedByUserId,
        escalatedAt: input.now.toISOString(),
      }),
    );
  }

  /**
   * Record the final moderation decision on this report.
   *
   * Throws `AppError.conflict('reports.reportAlreadyResolved', ...)` if the
   * report has already been resolved — append-only invariant enforced by the
   * domain for legal compliance.
   *
   * When the report is escalated, the caller must supply either:
   *   - `externalInputCount > 0` (an external-input row exists), OR
   *   - a non-empty `overrideReason`
   * For categories `criminal-content` and `imminent-harm`, `overrideReason`
   * is prohibited regardless (legal Q2 enforcement).
   *
   * Records `reports.reportResolved`.
   */
  resolve(input: {
    resolution: 'hidden' | 'kept';
    resolvedByUserId: string;
    now: Date;
    overrideReason?: string | null;
    externalInputCount?: number;
  }): void {
    const overrideReason = input.overrideReason ?? null;
    const externalInputCount = input.externalInputCount ?? 0;

    if (this._resolvedAt !== null) {
      throw AppError.conflict('Report has already been resolved', {
        subcode: 'reports.reportAlreadyResolved',
      });
    }

    if (this._escalatedAt === null) {
      // Non-escalated path — overrideReason must not be set.
      if (overrideReason !== null) {
        throw AppError.validation('Override reason only valid on escalated reports', {
          subcode: 'reports.overrideRequiresEscalation',
        });
      }
    } else {
      // Escalated path — `_escalationCategory` is invariantly non-null whenever
      // `_escalatedAt` is non-null (set atomically in `escalate()`).
      const category = this._escalationCategory as EscalationCategory;
      // Enforce category-specific and workflow guards.
      const prohibitedCategories: EscalationCategory[] = ['criminal-content', 'imminent-harm'];
      if (overrideReason !== null && prohibitedCategories.includes(category)) {
        throw AppError.validation(`Override not permitted for category ${category}`, {
          subcode: 'reports.overrideForbiddenForCategory',
        });
      }
      if (externalInputCount === 0 && overrideReason === null) {
        throw AppError.conflict(
          'Report is escalated; resolve requires external-input row or --override-reason',
          { subcode: 'reports.escalationResolveBlocked' },
        );
      }
      if (overrideReason !== null && overrideReason.trim().length === 0) {
        throw AppError.validation('Override reason required', {
          subcode: 'reports.overrideReasonRequired',
        });
      }
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

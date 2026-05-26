import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Report } from '../entities/report.js';

/**
 * Keyset cursor for paginated report listings. Encodes (createdAt, id) of
 * the last item on the previous page. Callers treat this as opaque.
 */
export interface ReportCursor {
  lastCreatedAt: Date;
  lastReportId: string;
}

export interface ReportRepository {
  save(report: Report, ctx?: TxContext): Promise<void>;

  findById(id: string, ctx?: TxContext): Promise<Report | null>;

  /**
   * Cursor-paginated listing of unresolved reports (resolvedAt IS NULL),
   * ordered createdAt ASC, id ASC (oldest-first for moderation queue).
   * Default limit: 20, max: 100.
   */
  listUnresolved(
    input: { cursor?: string; limit?: number },
    ctx?: TxContext,
  ): Promise<{ rows: Report[]; nextCursor: string | null }>;

  /**
   * List reports resolved before the given cutoff date.
   * Used by Brief 3B's retention sweep.
   */
  listOlderThan(input: { resolvedAtBefore: Date }, ctx?: TxContext): Promise<Report[]>;

  /**
   * List unresolved reports created before the given cutoff.
   * Used to flag reports that have been open for more than 7 days.
   */
  listOpenOlderThan(input: { createdAtBefore: Date }, ctx?: TxContext): Promise<Report[]>;

  /**
   * Cursor-paginated listing of reports filed by a specific user.
   * Ordered createdAt DESC, id DESC.
   */
  listByReporter(
    input: { reporterUserId: string; cursor?: string; limit?: number },
    ctx?: TxContext,
  ): Promise<{ rows: Report[]; nextCursor: string | null }>;

  /**
   * PDPA-deletion method. MUST be invoked inside a UnitOfWork.run(...) closure;
   * `ctx` is required (not optional) because this method's only legitimate
   * callers are retention/sweep use cases that own the transaction boundary.
   * Documented A6 carve-out: see CLAUDE.md "evidence-integrity required-ctx"
   * — extended to cover PDPA-deletion repository methods.
   *
   * Bulk-delete all reports associated with a user as part of a PDPA erasure
   * cascade. Deletes:
   *   (a) reports filed BY the user (`reporterUserId = userId`), and
   *   (b) reports where `targetType = 'review'` and `targetId` points at a
   *       review the user authored or was rated in.
   *
   * NOTE: Polymorphic resolvers for `targetType IN ('user', 'event')` are
   * deferred — see TRI-30 spec and TRI-155 PM brief. Add resolver branches
   * here and in the Prisma repository implementation when those target types
   * are implemented.
   *
   * @returns The number of report rows deleted.
   */
  deleteAllForUser(userId: string, ctx: TxContext): Promise<number>;

  /**
   * PDPA-deletion method. MUST be invoked inside a UnitOfWork.run(...) closure;
   * `ctx` is required (not optional) because this method's only legitimate
   * callers are retention/sweep use cases that own the transaction boundary.
   * Documented A6 carve-out: see CLAUDE.md "evidence-integrity required-ctx"
   * — extended to cover PDPA-deletion repository methods.
   *
   * Delete a single report row by its primary key. The deletion is atomic with
   * the upstream audit reference severance (TRI-198 report-retention sweep).
   */
  deleteById(id: string, ctx: TxContext): Promise<void>;

  /**
   * Returns the distinct set of `originatingReportId` values present in
   * `moderation_action_audit` that have no corresponding row in
   * `moderation_reports` (anti-join).
   *
   * Used by the report-retention sweep's orphan-reference defensive pass to
   * NULL-out dangling foreign references left by prior partial failures or
   * out-of-order deletions.
   *
   * Placement: the report bounded context owns "what is a valid report"; the
   * anti-join reads both `moderation_action_audit` and `moderation_reports`,
   * which is the same cross-table pattern already present in `deleteAllForUser`
   * (reads `reviews` to expand the report target set). Documented A11 carve-out.
   *
   * Optional ctx — orphan severance runs outside the per-report transaction.
   */
  findOrphanedOriginatingReportIds(ctx?: TxContext): Promise<string[]>;
}

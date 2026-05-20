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
}

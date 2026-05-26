import type { TxContext } from '@/core/db/unit-of-work.port.js';

/**
 * A single execution record for a scheduled sweep job.
 *
 * Written once per tick (regardless of success or failure) to provide
 * an audit trail answering "did the sweep run on date X?" for App Store
 * / regulator requests.
 *
 * `auditRowsSevered`: NULL for sweep kinds that don't sever cross-references
 * (selfie-retention-sweep); an integer count for sweep kinds that do
 * (report-retention-sweep).
 */
export interface SweepRunEntry {
  id: string;
  kind: string; // 'selfie-retention-sweep' for this use case; extensible
  startedAt: Date;
  finishedAt: Date | null;
  evaluated: number;
  deleted: number;
  failed: number;
  reaperRetried: number;
  reaperSucceeded: number;
  error: string | null;
  auditRowsSevered: number | null;
}

export interface SweepRunRepository {
  /**
   * Record one sweep tick. `ctx` is optional because the write is intentionally
   * OUTSIDE the per-record unit-of-work (the row describes the entire tick, not
   * a single record). The row is written after all per-record transactions have
   * committed (or failed), so it cannot participate in a per-record tx.
   */
  record(entry: SweepRunEntry, ctx?: TxContext): Promise<void>;
}

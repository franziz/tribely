/**
 * Result returned by SweepResolvedReportsUseCase after one sweep tick.
 *
 * - `evaluated`: total resolved reports older than 12 months found by the main pass.
 * - `deleted`: reports successfully deleted (severed + deleted atomically).
 * - `failed`: reports where the per-report transaction threw; these remain in the DB
 *   and will be retried on the next sweep tick.
 * - `auditRowsSevered`: count of `moderation_action_audit.originatingReportId` fields
 *   NULLed during the main pass (across all successfully deleted reports).
 * - `orphanRowsSevered`: count of audit rows severed during the orphan-reference
 *   defensive pass (rows pointing at non-existent reports).
 * - `durationMs`: wall-clock milliseconds from start to return.
 *
 * The `sweep_runs` row written each tick stores `auditRowsSevered + orphanRowsSevered`
 * as its combined `auditRowsSevered` column for the regulator audit trail.
 */
export interface SweepResolvedReportsResult {
  evaluated: number;
  deleted: number;
  failed: number;
  auditRowsSevered: number;
  orphanRowsSevered: number;
  durationMs: number;
}

/**
 * Result returned by PrunePostEventCheckInsUseCase.
 *
 * Three retention buckets are swept independently:
 *   - pendingDeleted:         `pending` rows older than 30 days from createdAt
 *   - okDeleted:              `ok` rows older than 90 days from createdAt
 *   - flaggedResolvedDeleted: `flagged` rows with a non-null resolvedAt older
 *                             than 12 months from resolvedAt
 *
 * Note: `flagged` rows with resolvedAt IS NULL are NEVER deleted by sweep.
 *
 * Per A17 (non-trivial multi-field result), this shape is a named DTO rather
 * than an inline object type.
 */
export interface PrunePostEventCheckInsResult {
  pendingDeleted: number;
  okDeleted: number;
  flaggedResolvedDeleted: number;
}

export interface PrunePostEventCheckInEventsResult {
  pruned: number;
  cutoff: Date;
  durationMs: number;
}

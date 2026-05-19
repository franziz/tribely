export interface SweepRetainedSelfiesResult {
  evaluated: number;
  deleted: number;
  failed: number;
  reaperRetried: number;
  reaperSucceeded: number;
  durationMs: number;
}

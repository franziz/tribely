/**
 * Outbound port for "now". Injected so use cases stay deterministic in tests.
 * In production, the SystemClock returns `new Date()`.
 */
export interface Clock {
  now(): Date;
}

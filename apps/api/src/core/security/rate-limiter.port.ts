/**
 * Outbound port for rate limiting. Lives in `core` because rate limiting
 * is a cross-cutting concern, not a property of any one bounded context.
 *
 * Implementations decide storage (in-memory for dev / single-instance MVP,
 * Redis for production multi-instance deployments). The `key` is composed
 * by callers (e.g. `'sign-in:' + ip`, `'sign-up:' + email`).
 */
export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
}

export interface RateLimiter {
  /**
   * Try to consume one unit from the bucket identified by `key`.
   * Returns `allowed: false` if the bucket is empty.
   */
  consume(key: string, limit: number, windowSeconds: number): Promise<RateLimitResult>;
}

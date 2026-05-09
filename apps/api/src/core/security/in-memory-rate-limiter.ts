import type { RateLimiter, RateLimitResult } from './rate-limiter.port.js';

interface Bucket {
  count: number;
  resetAt: number;
}

/**
 * In-memory rate limiter — sufficient for single-instance dev / MVP.
 * For multi-instance production, swap with a Redis-backed adapter that
 * implements the same RateLimiter port — no caller changes required.
 */
export class InMemoryRateLimiter implements RateLimiter {
  private readonly buckets = new Map<string, Bucket>();

  // No `async` — the interface returns Promise but this in-memory impl is
  // synchronous. Wrapping with Promise.resolve avoids `require-await` while
  // honoring the port contract (callers always await).
  consume(key: string, limit: number, windowSeconds: number): Promise<RateLimitResult> {
    const now = Date.now();
    const existing = this.buckets.get(key);

    if (!existing || existing.resetAt <= now) {
      const fresh: Bucket = { count: 1, resetAt: now + windowSeconds * 1000 };
      this.buckets.set(key, fresh);
      return Promise.resolve({
        allowed: true,
        remaining: Math.max(0, limit - 1),
        resetAt: new Date(fresh.resetAt),
      });
    }

    if (existing.count >= limit) {
      return Promise.resolve({
        allowed: false,
        remaining: 0,
        resetAt: new Date(existing.resetAt),
      });
    }

    existing.count += 1;
    return Promise.resolve({
      allowed: true,
      remaining: Math.max(0, limit - existing.count),
      resetAt: new Date(existing.resetAt),
    });
  }
}

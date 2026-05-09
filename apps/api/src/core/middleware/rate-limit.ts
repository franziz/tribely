import type { Context, MiddlewareHandler } from 'hono';
import { AppError } from '../errors/app-error.js';
import type { RateLimiter } from '../security/rate-limiter.port.js';

export interface RateLimitOptions {
  limit: number;
  windowSeconds: number;
  /** Function to compute the bucket key from the request. Default: client IP. */
  keyFor?: (c: Context) => string;
  /** Logical name shown in error details, e.g. 'sign-in'. */
  bucket: string;
}

const defaultKey = (c: Context): string => {
  // Hono runs behind reverse proxies in production. Honor x-forwarded-for if
  // the deployer trusts it; otherwise fall back to remote addr from the env.
  const xff = c.req.header('x-forwarded-for');
  if (xff) {
    // `split(',')` always returns ≥1 element when xff is non-empty, but TS
    // can't prove that — use `?? xff` rather than a non-null assertion.
    const first = xff.split(',')[0] ?? xff;
    return first.trim();
  }
  return c.req.header('cf-connecting-ip') ?? 'unknown';
};

/**
 * Rate-limit middleware. On exceed, throws AppError with code VALIDATION_ERROR
 * (mapped to 429 below). Suitable for sign-in / sign-up / refresh hot paths.
 */
export const rateLimit = (limiter: RateLimiter, options: RateLimitOptions): MiddlewareHandler => {
  const compose = options.keyFor ?? defaultKey;
  return async (c, next) => {
    const key = `${options.bucket}:${compose(c)}`;
    const result = await limiter.consume(key, options.limit, options.windowSeconds);
    c.header('X-RateLimit-Limit', String(options.limit));
    c.header('X-RateLimit-Remaining', String(result.remaining));
    c.header('X-RateLimit-Reset', String(Math.ceil(result.resetAt.getTime() / 1000)));
    if (!result.allowed) {
      const retryAfter = Math.max(1, Math.ceil((result.resetAt.getTime() - Date.now()) / 1000));
      c.header('Retry-After', String(retryAfter));
      throw new AppError('VALIDATION_ERROR', `Rate limit exceeded for ${options.bucket}`, 429, {
        retryAfterSeconds: retryAfter,
      });
    }
    await next();
  };
};

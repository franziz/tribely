import type { MiddlewareHandler } from 'hono';
import { AppError } from '../errors/app-error.js';
import { PhoneNumber } from '../sms/phone-number.js';
import type { RateLimiter } from '../security/rate-limiter.port.js';

export interface RateLimitByPhoneOptions {
  bucket: string;
  limit: number;
  windowSeconds: number;
}

/**
 * Rate-limit middleware keyed on the phone number in the request body.
 *
 * Must run BEFORE `zValidator` — it reads the raw JSON body via
 * `c.req.json()`. Hono buffers the parsed body internally, so `zValidator`
 * can re-read the same body after this middleware.
 *
 * Key derivation:
 *   - Parse failure (non-JSON body)  → key `${bucket}:malformed`
 *     Let `zValidator` produce the user-facing 400; this middleware passes through.
 *   - Invalid E.164                  → key `${bucket}:invalid`
 *     Same policy: let `zValidator` / domain validation produce the user-facing error.
 *   - Valid E.164                    → key `${bucket}:${normalized}`
 *
 * On bucket exhaustion: sets standard rate-limit headers and throws AppError
 * with code VALIDATION_ERROR (HTTP 429) — matching the existing `rateLimit`
 * middleware convention.
 *
 * The `rateLimiter` instance is injected by the route factory so the middleware
 * reuses the same in-memory / Redis bucket store as all other rate limits.
 */
export const rateLimitByPhone =
  (
    limiter: RateLimiter,
    options: RateLimitByPhoneOptions,
  ): MiddlewareHandler =>
  async (c, next) => {
    // Attempt to parse the body. On failure (not JSON, empty body, etc.)
    // fall through with a sentinel key so zValidator handles the error.
    let phoneKey: string;
    try {
      // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
      const body = await c.req.json();
      // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
      const rawPhone = typeof body?.phone === 'string' ? (body.phone as string) : null;
      if (rawPhone === null) {
        phoneKey = `${options.bucket}:malformed`;
      } else {
        try {
          const phone = PhoneNumber.create(rawPhone);
          phoneKey = `${options.bucket}:${phone.value}`;
        } catch {
          // Invalid E.164 — let domain validation downstream produce the error.
          phoneKey = `${options.bucket}:invalid`;
        }
      }
    } catch {
      // Body parse failed — not JSON or empty.
      phoneKey = `${options.bucket}:malformed`;
    }

    const result = await limiter.consume(phoneKey, options.limit, options.windowSeconds);
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

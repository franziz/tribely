import { createId } from '@paralleldrive/cuid2';
import { createMiddleware } from 'hono/factory';
import { runWithContext, type RequestContext } from '../context/request-context.js';

/**
 * Variables set by this middleware on the Hono context for downstream
 * handlers / middleware to read.
 */
export interface RequestContextVariables {
  requestId: string;
}

/**
 * Hono middleware that opens an AsyncLocalStorage frame for every request
 * carrying a stable `requestId`. Must be registered EARLY in the chain —
 * before routes, before `requireAuth`, before any code that publishes
 * domain events.
 *
 * Behavior:
 *   - Reads `X-Request-Id` from the inbound request when present (lets
 *     callers — mobile, future webhooks — supply their own correlation id
 *     for distributed tracing). Otherwise generates a fresh `cuid2`.
 *   - Sets the same id on the response `X-Request-Id` header for the
 *     client to capture in error reports.
 *   - Wraps `next()` in `runWithContext` so any `getRequestContext()` call
 *     inside the request lifecycle sees `{ requestId, actorUserId: null }`.
 *
 * `actorUserId` is filled in later by `requireAuth` (see `upgradeActorUserId`
 * in core/context/request-context.ts). Anonymous routes (sign-up, sign-in)
 * keep `actorUserId: null` for the entire request — that's the audit truth.
 */
export const requestContext = () =>
  createMiddleware<{ Variables: RequestContextVariables }>(async (c, next) => {
    const inbound = c.req.header('X-Request-Id');
    // Cap inbound id length so a malicious caller can't blow up our audit
    // log columns with a 1MB header value. cuid2 produces ~24-char ids;
    // 128 is generous for any reasonable distributed-trace id format.
    const requestId = inbound && inbound.length > 0 && inbound.length <= 128 ? inbound : createId();

    c.set('requestId', requestId);
    c.header('X-Request-Id', requestId);

    const frame: RequestContext = { requestId, actorUserId: null };
    await runWithContext(frame, next);
  });

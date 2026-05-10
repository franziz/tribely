import { createMiddleware } from 'hono/factory';
import { logger } from './logger.js';
import { AppError } from '../errors/app-error.js';
import type { RecordHttpCallUseCase } from '@/features/audit/application/usecases/record-http-call.usecase.js';

/**
 * Hono middleware that records one row per inbound HTTP request to
 * `http_audit_logs`. Must run AFTER `requestContext` (needs the requestId)
 * and AFTER `requireAuth` on protected routes (so actorUserId is set).
 *
 * The recording happens *after* `next()` returns, so by the time we read
 * the response we see the final status — including the status set by the
 * global `errorHandler` when an exception was thrown. `c.error` carries
 * the original exception when `errorHandler` ran; we extract the AppError
 * code if applicable.
 *
 * Body content is intentionally not captured — PDPA-friendly. Headers,
 * status, duration, and actor identity are sufficient for forensics; full
 * request payloads remain in `outbox_events` (sans secrets).
 *
 * Failures to record audit are logged WARN and swallowed: the original
 * response must not be derailed because the audit pipeline hiccupped.
 */
export const auditHttp = (recorder: RecordHttpCallUseCase) =>
  createMiddleware(async (c, next) => {
    const startedAt = Date.now();
    await next();
    const durationMs = Date.now() - startedAt;

    const requestId = c.get('requestId') as string | undefined;
    if (!requestId) {
      // requestContext middleware not in chain — log a loud warn and skip.
      // Skipping is the only safe option; we don't have a correlation key.
      logger.warn(
        { method: c.req.method, path: c.req.path, status: c.res.status },
        'auditHttp: no requestId on context — was requestContext() registered before routes?',
      );
      return;
    }

    const actorUserId = (c.get('userId') as string | undefined) ?? null;
    const errorCode = c.error instanceof AppError ? c.error.code : null;

    try {
      await recorder.execute({
        requestId,
        method: c.req.method,
        path: c.req.path,
        status: c.res.status,
        durationMs,
        actorUserId,
        ip: extractIp(c.req.header('x-forwarded-for'), c.req.header('cf-connecting-ip')),
        userAgent: c.req.header('user-agent') ?? null,
        errorCode,
        receivedAt: new Date(startedAt),
      });
    } catch (err) {
      logger.warn({ err, requestId, path: c.req.path }, 'auditHttp: failed to persist audit row');
    }
  });

const extractIp = (xff: string | undefined, cf: string | undefined): string | null => {
  if (xff && xff.length > 0) {
    const first = xff.split(',')[0]?.trim();
    if (first && first.length > 0) return first;
  }
  if (cf && cf.length > 0) return cf;
  return null;
};

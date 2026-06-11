import { createMiddleware } from 'hono/factory';
import { env } from '../config/env.js';
import { AppError } from '../errors/app-error.js';
import type { Logger } from '../observability/logger.port.js';

/**
 * Hono middleware factory: refuses selfie intake requests in production
 * until the deletion-automation safety gate is confirmed ready.
 *
 * In NODE_ENV=production, throws `AppError.selfieIntakeDisabled` (503) when
 * `SELFIE_DELETION_AUTOMATION_READY` is falsy. Also emits a WARN-level log
 * line so operators know a real call was refused (not just a misconfiguration).
 *
 * In development / test / staging (NODE_ENV !== 'production'), this middleware
 * is a transparent no-op — the gate is always open outside production.
 *
 * Rationale: selfie intake in production without a confirmed running retention
 * sweep would accumulate user selfie images with no scheduled deletion path,
 * violating PDPA s25 retention commitments. The gate is explicit (not inferred
 * from key presence) so activation is deliberate and logged. See TRI-23.
 *
 * Mount order: requireAuth → requireSelfieIntakeEnabled → handler.
 */
export const requireSelfieIntakeEnabled = (logger: Logger) =>
  createMiddleware(async (c, next) => {
    if (env.NODE_ENV === 'production' && !env.SELFIE_DELETION_AUTOMATION_READY) {
      logger.warn(
        {},
        'selfie intake refused: deletion automation not confirmed ready ' +
          '(set SELFIE_DELETION_AUTOMATION_READY=true when the retention sweep ' +
          'has been observed emitting deletion-event rows in production run-logs)',
      );
      throw AppError.selfieIntakeDisabled(
        'Selfie intake is temporarily unavailable — identity verification is not yet enabled.',
      );
    }
    await next();
  });

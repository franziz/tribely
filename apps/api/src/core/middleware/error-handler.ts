import type { ErrorHandler } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { routePath } from 'hono/route';
import { ZodError } from 'zod';
import { AppError } from '../errors/app-error.js';
import { logger } from './logger.js';
import { captureAppError, captureUnhandled } from '../observability/sentry.js';

export const errorHandler: ErrorHandler = (err, c) => {
  if (err instanceof AppError) {
    // Capture handled AppError to Sentry with safe request context.
    // AppError.details is deliberately NOT passed — Rule 8 (PDPA): details is
    // typed as `unknown` and must never egress to Sentry. The capture helper
    // takes only the error object + allowlisted context.
    // `routePath(c)` returns the matched route template (e.g. '/events/:id'),
    // NOT the raw URL — per Rule 13.
    captureAppError(err, {
      method: c.req.method,
      path: routePath(c),
      status: err.status,
      errorCode: err.code,
    });

    return c.json(
      { error: { code: err.code, message: err.message, details: err.details } },
      err.status as never,
    );
  }

  if (err instanceof ZodError) {
    return c.json(
      { error: { code: 'VALIDATION_ERROR', message: 'Invalid input', details: err.flatten() } },
      400,
    );
  }

  if (err instanceof HTTPException) {
    return err.getResponse();
  }

  logger.error({ err }, 'Unhandled error');
  // Capture unhandled error to Sentry with safe request context.
  captureUnhandled(err, {
    method: c.req.method,
    path: routePath(c),
    status: 500,
    errorCode: 'INTERNAL',
  });
  return c.json({ error: { code: 'INTERNAL', message: 'Internal server error' } }, 500);
};

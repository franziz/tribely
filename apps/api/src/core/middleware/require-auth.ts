import { createMiddleware } from 'hono/factory';
import { upgradeActorUserId } from '../context/request-context.js';
import { AppError } from '../errors/app-error.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';

/**
 * The set of variables the auth middleware writes into the Hono request context.
 * Downstream route handlers read `c.var.userId` (or `c.get('userId')`).
 */
export type AuthVariables = {
  userId: string;
  email: string;
};

/**
 * Hono middleware factory: requires a valid `Authorization: Bearer <jwt>` header.
 * Verifies the access token via the AccessTokenIssuer port; on success, sets
 * userId + email in the request context AND upgrades the AsyncLocalStorage
 * frame so the audit trail records the authenticated actor on outbox events
 * + HTTP audit rows. On any failure, throws AppError.unauthorized.
 *
 * Must run AFTER `requestContext` middleware — it relies on the ALS frame
 * already being open.
 */
export const requireAuth = (tokens: AccessTokenIssuer) =>
  createMiddleware<{ Variables: AuthVariables }>(async (c, next) => {
    const header = c.req.header('Authorization');
    if (!header || !header.startsWith('Bearer ')) {
      throw AppError.unauthorized('Missing bearer token');
    }
    const subject = await tokens.verify(header.slice('Bearer '.length).trim());
    c.set('userId', subject.userId);
    c.set('email', subject.email);
    await upgradeActorUserId(subject.userId, next);
  });

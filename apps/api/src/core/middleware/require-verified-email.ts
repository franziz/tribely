import { createMiddleware } from 'hono/factory';
import { AppError } from '../errors/app-error.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { AuthVariables } from './require-auth.js';

/**
 * Hono middleware factory: requires the authenticated user to have a verified
 * email. Must run AFTER `requireAuth` so `c.var.userId` is populated.
 *
 * On a non-verified user, throws AppError with code 'EMAIL_NOT_VERIFIED' (HTTP
 * 403). The mobile client uses this code to route the user back to the
 * verify-email screen instead of treating it as a hard auth failure.
 *
 * Not yet wired to any route — `events` endpoints (TRI-9 / TRI-19 / TRI-26
 * etc.) and join-request endpoints (TRI-20) are the intended targets per the
 * TRI-15 acceptance criteria. Sign-in / sign-up / verify-email itself must
 * NOT be gated.
 */
export const requireVerifiedEmail = (users: UserRepository) =>
  createMiddleware<{ Variables: AuthVariables }>(async (c, next) => {
    const user = await users.findById(c.get('userId'));
    if (!user) {
      // Token referenced a deleted user — tell the client the session is dead.
      throw AppError.unauthorized('User not found');
    }
    if (!user.isEmailVerified()) {
      throw AppError.emailNotVerified(
        'Verify your email before performing this action.',
      );
    }
    await next();
  });

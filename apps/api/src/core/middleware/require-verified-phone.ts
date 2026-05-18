import { createMiddleware } from 'hono/factory';
import { AppError } from '../errors/app-error.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { AuthVariables } from './require-auth.js';

/**
 * Hono middleware factory: requires the authenticated user to have a verified
 * phone number. Must run AFTER `requireAuth` so `c.var.userId` is populated.
 *
 * On an unverified user (phone is null OR phoneVerifiedAt is null), throws
 * AppError with code 'PHONE_NOT_VERIFIED' (HTTP 403). The mobile client uses
 * this code to route the user to the phone verification screen instead of
 * treating it as a hard auth failure.
 *
 * Note: only `phoneVerifiedAt` is checked, not `phone`. A user whose phone
 * was revoked (phone hash cleared on contested takeover) but who has not yet
 * re-verified will also be gated — this is the correct behaviour per SWE-8.
 *
 * Not yet wired to any route — `events` endpoints and join-request endpoints
 * are the intended targets per the TRI-16 acceptance criteria. Sign-in /
 * sign-up / verify-phone itself must NOT be gated.
 */
export const requireVerifiedPhone = (users: UserRepository) =>
  createMiddleware<{ Variables: AuthVariables }>(async (c, next) => {
    const user = await users.findById(c.get('userId'));
    if (!user) {
      // Token referenced a deleted user — tell the client the session is dead.
      throw AppError.unauthorized('User not found');
    }
    if (user.phoneVerifiedAt === null) {
      throw AppError.phoneNotVerified('Verify your phone before performing this action.');
    }
    await next();
  });

import { createMiddleware } from 'hono/factory';
import { AppError } from '../errors/app-error.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { AuthVariables } from './require-auth.js';

/**
 * Hono middleware factory: requires the authenticated user to have an approved
 * selfie. Must run AFTER `requireAuth` so `c.var.userId` is populated.
 *
 * On an unapproved user (selfieStatus is null, 'pending', or 'rejected'),
 * throws AppError with code 'SELFIE_NOT_VERIFIED' (HTTP 403). The mobile
 * client uses this code to route the user to the selfie capture screen instead
 * of treating it as a hard auth failure.
 *
 * Only `selfieStatus === 'approved'` passes the gate. A user whose selfie has
 * never been submitted, is pending review, or was rejected will be gated — this
 * is the correct behaviour per TRI-23 acceptance criteria.
 *
 * Gate ordering (full chain): requireAuth → requireVerifiedEmail →
 *   requireVerifiedPhone → requireVerifiedSelfie → handler.
 *
 * Sign-in / sign-up / verify / selfie-intake endpoints must NOT be gated —
 * only state-changing mutations on events and join-requests.
 */
export const requireVerifiedSelfie = (users: UserRepository) =>
  createMiddleware<{ Variables: AuthVariables }>(async (c, next) => {
    const user = await users.findById(c.get('userId'));
    if (!user) {
      // Token referenced a deleted user — tell the client the session is dead.
      throw AppError.unauthorized('User not found');
    }
    if (user.selfieStatus !== 'approved') {
      throw AppError.selfieNotVerified(
        'Verify your identity with a selfie before performing this action.',
      );
    }
    await next();
  });

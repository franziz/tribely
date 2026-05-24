import { createMiddleware } from 'hono/factory';
import { AppError } from '../errors/app-error.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { AuthVariables } from './require-auth.js';

/**
 * Hono middleware factory: requires the authenticated user to be an admin.
 * Must run AFTER `requireAuth` so `c.var.userId` is populated.
 *
 * - Throws AppError.unauthorized('User not found') if the user record is
 *   missing (deleted account / stale token).
 * - Throws AppError.forbidden('Admin required') if the user exists but is
 *   not an admin.
 * - Calls next() if the user has isAdmin === true.
 *
 * Error messages are deliberately generic — no userId, email, or any user
 * attribute is included to prevent information leakage (AC #6).
 */
export const requireAdmin = (users: UserRepository) =>
  createMiddleware<{ Variables: AuthVariables }>(async (c, next) => {
    const user = await users.findById(c.get('userId'));
    if (!user) {
      throw AppError.unauthorized('User not found');
    }
    if (!user.isAdmin) {
      throw AppError.forbidden('Admin required');
    }
    await next();
  });

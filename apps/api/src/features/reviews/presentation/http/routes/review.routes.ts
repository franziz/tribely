import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import { requireVerifiedEmail } from '@/core/middleware/require-verified-email.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { ReviewController } from '../controllers/review.controller.js';
import {
  editReviewBodySchema,
  listReviewsQuerySchema,
  submitReviewBodySchema,
} from '../schemas/review.schemas.js';

export interface ReviewRouteDeps {
  controller: ReviewController;
  accessTokens: AccessTokenIssuer;
  userRepository: UserRepository;
}

/**
 * Mounted at /events — handles:
 *   POST /events/:eventId/reviews            — submit a review
 *   GET  /events/:eventId/review-eligibility — eligibility read (auth-only, no verifiedEmail)
 *
 * The Hono additive mount pattern (CLAUDE.md gotcha): app.route('/events',
 * buildEventRoutes(...)) and app.route('/events', buildEventScopedReviewRoutes(...))
 * BOTH mount under /events and merge their path trees. No overrides occur.
 *
 * Guard rationale: eligibility is a read, not a state-changing write, so it
 * requires only `requireAuth` — matching the GET /users/:userId/reviews guard.
 */
export const buildEventScopedReviewRoutes = (
  deps: ReviewRouteDeps,
): Hono<{ Variables: AuthVariables }> => {
  const { controller } = deps;
  const auth = requireAuth(deps.accessTokens);
  const verifiedEmail = requireVerifiedEmail(deps.userRepository);

  return new Hono<{ Variables: AuthVariables }>()
    .post(
      '/:eventId/reviews',
      auth,
      verifiedEmail,
      zValidator('json', submitReviewBodySchema),
      (c) =>
        controller.submitAction(c, c.get('userId'), c.req.param('eventId'), c.req.valid('json')),
    )
    .get('/:eventId/review-eligibility', auth, (c) =>
      controller.eligibilityAction(c, c.get('userId'), c.req.param('eventId')),
    );
};

/**
 * Mounted at /reviews — handles PATCH /reviews/:reviewId.
 */
export const buildReviewRoutes = (deps: ReviewRouteDeps): Hono<{ Variables: AuthVariables }> => {
  const { controller } = deps;
  const auth = requireAuth(deps.accessTokens);
  const verifiedEmail = requireVerifiedEmail(deps.userRepository);

  return new Hono<{ Variables: AuthVariables }>().patch(
    '/:reviewId',
    auth,
    verifiedEmail,
    zValidator('json', editReviewBodySchema),
    (c) => controller.editAction(c, c.get('userId'), c.req.param('reviewId'), c.req.valid('json')),
  );
};

/**
 * Mounted at /users — handles GET /users/:userId/reviews.
 *
 * Merges with the existing /users mount in app.ts (Hono additive pattern).
 */
export const buildUserScopedReviewRoutes = (
  deps: ReviewRouteDeps,
): Hono<{ Variables: AuthVariables }> => {
  const { controller } = deps;
  const auth = requireAuth(deps.accessTokens);

  return new Hono<{ Variables: AuthVariables }>().get(
    '/:userId/reviews',
    auth,
    zValidator('query', listReviewsQuerySchema),
    (c) =>
      controller.listForUserAction(c, c.get('userId'), c.req.param('userId'), c.req.valid('query')),
  );
};

/**
 * Mounted at /me — handles GET /me/reviews/written.
 *
 * Merges with the existing /me mount in app.ts (Hono additive pattern).
 */
export const buildMyReviewRoutes = (deps: ReviewRouteDeps): Hono<{ Variables: AuthVariables }> => {
  const { controller } = deps;
  const auth = requireAuth(deps.accessTokens);

  return new Hono<{ Variables: AuthVariables }>().get(
    '/reviews/written',
    auth,
    zValidator('query', listReviewsQuerySchema),
    (c) => controller.listWrittenAction(c, c.get('userId'), c.req.valid('query')),
  );
};

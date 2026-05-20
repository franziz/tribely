import { Hono, type Context } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { rateLimit } from '@/core/middleware/rate-limit.js';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import { requireVerifiedEmail } from '@/core/middleware/require-verified-email.js';
import type { RateLimiter } from '@/core/security/rate-limiter.port.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { UserBlockController } from '../controllers/user-block.controller.js';
import { blockUserBodySchema, listMyBlocksQuerySchema } from '../schemas/user-block.schemas.js';

export interface UserBlockRouteDeps {
  controller: UserBlockController;
  accessTokens: AccessTokenIssuer;
  userRepository: UserRepository;
  rateLimiter: RateLimiter;
}

/**
 * Mounted at /me — handles:
 *   POST   /me/blocks              — block a user
 *   DELETE /me/blocks/:blockedUserId — unblock a user
 *   GET    /me/blocks              — list my blocks
 *
 * Rate limit: 50 blocks per day per authenticated user.
 * Auth + email-verified required on all routes.
 *
 * Uses the Hono additive mount pattern (CLAUDE.md gotcha): this router is
 * mounted at `/me` alongside other /me/* routers — non-overlapping paths.
 */
export const buildUserBlockRoutes = (
  deps: UserBlockRouteDeps,
): Hono<{ Variables: AuthVariables }> => {
  const { controller } = deps;
  const auth = requireAuth(deps.accessTokens);
  const verifiedEmail = requireVerifiedEmail(deps.userRepository);

  const userKey = (c: Context): string =>
    (c as Context<{ Variables: AuthVariables }>).get('userId');

  const limitBlock = rateLimit(deps.rateLimiter, {
    bucket: 'user-blocks-create',
    limit: 50,
    windowSeconds: 24 * 60 * 60, // 1 day
    keyFor: userKey,
  });

  return new Hono<{ Variables: AuthVariables }>()
    .post(
      '/blocks',
      auth,
      verifiedEmail,
      limitBlock,
      zValidator('json', blockUserBodySchema),
      (c) => controller.blockAction(c, c.get('userId'), c.req.valid('json')),
    )
    .delete('/blocks/:blockedUserId', auth, verifiedEmail, (c) =>
      controller.unblockAction(c, c.get('userId'), c.req.param('blockedUserId')),
    )
    .get('/blocks', auth, verifiedEmail, zValidator('query', listMyBlocksQuerySchema), (c) =>
      controller.listAction(c, c.get('userId'), c.req.valid('query')),
    );
};

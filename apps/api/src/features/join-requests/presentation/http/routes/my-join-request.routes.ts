import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import { requireVerifiedEmail } from '@/core/middleware/require-verified-email.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { JoinRequestController } from '../controllers/join-request.controller.js';
import { listMyJoinRequestsQuerySchema } from '../schemas/join-request.schemas.js';

export interface MyJoinRequestRouteDeps {
  controller: JoinRequestController;
  accessTokens: AccessTokenIssuer;
  userRepository: UserRepository;
}

/**
 * Routes scoped to the authenticated user's own join requests.
 * Mounted at `/me` in `app.ts`.
 *
 * `GET /me/join-requests` — paginated list of the caller's own requests,
 * each enriched with an event summary. Optional `?eventId=:id` filter for
 * the mobile event-detail "do I have a request?" lookup.
 *
 * Auth requirements mirror every other endpoint in this feature:
 * `requireAuth + requireVerifiedEmail`.
 */
export const buildMyJoinRequestsRoutes = (
  deps: MyJoinRequestRouteDeps,
): Hono<{ Variables: AuthVariables }> => {
  const auth = requireAuth(deps.accessTokens);
  const verified = requireVerifiedEmail(deps.userRepository);

  return new Hono<{ Variables: AuthVariables }>().get(
    '/join-requests',
    auth,
    verified,
    zValidator('query', listMyJoinRequestsQuerySchema),
    (c) => deps.controller.listMineAction(c, c.get('userId'), c.req.valid('query')),
  );
};

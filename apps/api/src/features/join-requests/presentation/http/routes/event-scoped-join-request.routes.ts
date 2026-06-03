import { Hono, type Context } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { rateLimit } from '@/core/middleware/rate-limit.js';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import { requireVerifiedEmail } from '@/core/middleware/require-verified-email.js';
import { requireVerifiedPhone } from '@/core/middleware/require-verified-phone.js';
import type { RateLimiter } from '@/core/security/rate-limiter.port.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { JoinRequestController } from '../controllers/join-request.controller.js';
import {
  listJoinRequestsByEventQuerySchema,
  removeAttendeeBodySchema,
} from '../schemas/join-request.schemas.js';

export interface EventScopedJoinRequestRouteDeps {
  controller: JoinRequestController;
  accessTokens: AccessTokenIssuer;
  userRepository: UserRepository;
  rateLimiter: RateLimiter;
}

/**
 * Routes that conceptually live under `/events/:id/...` because the `event`
 * is the meaningful parent resource. Kept in a separate router from the
 * `/join-requests/:id/...` mutation routes because they mount at different
 * path prefixes in `app.ts`. Both routers share the same controller instance.
 *
 * All endpoints require auth + verified email — TRI-20 is the first feature
 * to wire `requireVerifiedEmail` per the TRI-15 acceptance criteria. Joining
 * strangers is the trust floor that requires a verified contact path.
 *
 * `POST /events/:id/join-requests` is rate-limited at 10/hour per user (not
 * per IP) — the cap should follow the actor across networks, mirroring the
 * `events-create` rate-limit pattern. Approve/reject/cancel/list have no
 * rate limit; hosts may bulk-approve a backlog at scale.
 *
 * IMPORTANT: `POST /:id/join-requests` has NO `zValidator('json', ...)` middleware.
 * The body is entirely optional (only carries an optional `acknowledgedSafetyReminder`
 * flag added in TRI-34). Mounting a JSON body validator triggers Hono's
 * `c.req.json()` path, which throws 400 on an empty body BEFORE any Zod schema
 * runs — breaking the mobile Dio client that always sets Content-Type: application/json
 * but sends no body. Tolerant body parsing is done inside `createAction` in the
 * controller instead (same pattern as the check-ins acknowledge route; see TRI-28
 * and TRI-34 for the empty-body trap history).
 */
export const buildEventScopedJoinRequestRoutes = (
  deps: EventScopedJoinRequestRouteDeps,
): Hono<{ Variables: AuthVariables }> => {
  const auth = requireAuth(deps.accessTokens);
  const verifiedEmail = requireVerifiedEmail(deps.userRepository);
  const verifiedPhone = requireVerifiedPhone(deps.userRepository);

  // `keyFor` runs after `requireAuth` populates `userId`. Casting the Context
  // lets us read the typed variable without a `string` assertion.
  const userKey = (c: Context): string =>
    (c as Context<{ Variables: AuthVariables }>).get('userId');
  const limitCreate = rateLimit(deps.rateLimiter, {
    bucket: 'join-requests-create',
    limit: 10,
    windowSeconds: 60 * 60,
    keyFor: userKey,
  });

  return new Hono<{ Variables: AuthVariables }>()
    .post(
      '/:id/join-requests',
      auth,
      verifiedEmail,
      verifiedPhone,
      limitCreate,
      // No zValidator — empty-body POST trap (see module JSDoc).
      (c) => deps.controller.createAction(c, c.req.param('id'), c.get('userId')),
    )
    .get(
      '/:id/join-requests',
      auth,
      verifiedEmail,
      verifiedPhone,
      zValidator('query', listJoinRequestsByEventQuerySchema),
      (c) =>
        deps.controller.listAction(c, c.req.param('id'), c.get('userId'), c.req.valid('query')),
    )
    .post(
      '/:id/join-requests/:joinRequestId/remove',
      auth,
      verifiedEmail,
      verifiedPhone,
      zValidator('json', removeAttendeeBodySchema),
      (c) =>
        deps.controller.removeAttendeeAction(
          c,
          c.req.param('joinRequestId'),
          c.get('userId'),
          c.req.valid('json'),
        ),
    );
};

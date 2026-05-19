import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import { requireVerifiedEmail } from '@/core/middleware/require-verified-email.js';
import { requireVerifiedPhone } from '@/core/middleware/require-verified-phone.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { JoinRequestController } from '../controllers/join-request.controller.js';
import { rejectJoinRequestBodySchema } from '../schemas/join-request.schemas.js';

export interface JoinRequestRouteDeps {
  controller: JoinRequestController;
  accessTokens: AccessTokenIssuer;
  userRepository: UserRepository;
}

/**
 * Mutation routes on the join-request aggregate itself, keyed by the
 * join-request id (NOT the event id). Approve/reject/cancel target a single
 * row — the event id is recoverable from the row, so the URL stays compact.
 *
 * Mounted at `/join-requests` in `app.ts`. All endpoints require auth +
 * verified email. No rate limit — hosts may need to bulk-approve a backlog,
 * and the aggregate enforces ownership / state transitions cheaply.
 */
export const buildJoinRequestRoutes = (
  deps: JoinRequestRouteDeps,
): Hono<{ Variables: AuthVariables }> => {
  const auth = requireAuth(deps.accessTokens);
  const verifiedEmail = requireVerifiedEmail(deps.userRepository);
  const verifiedPhone = requireVerifiedPhone(deps.userRepository);

  return new Hono<{ Variables: AuthVariables }>()
    .post('/:id/approve', auth, verifiedEmail, verifiedPhone, (c) =>
      deps.controller.approveAction(c, c.req.param('id'), c.get('userId')),
    )
    .post(
      '/:id/reject',
      auth,
      verifiedEmail,
      verifiedPhone,
      zValidator('json', rejectJoinRequestBodySchema),
      (c) =>
        deps.controller.rejectAction(c, c.req.param('id'), c.get('userId'), c.req.valid('json')),
    )
    .delete('/:id', auth, verifiedEmail, verifiedPhone, (c) =>
      deps.controller.cancelAction(c, c.req.param('id'), c.get('userId')),
    );
};

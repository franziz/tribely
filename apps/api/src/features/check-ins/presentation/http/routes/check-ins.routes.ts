import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { CheckInsController } from '../controllers/check-ins.controller.js';
import { flagCheckInBodySchema } from '../schemas/check-ins.schemas.js';

export interface CheckInsRouteDeps {
  controller: CheckInsController;
  accessTokens: AccessTokenIssuer;
}

/**
 * Routes for the post-event check-ins surface, scoped to the authenticated
 * user's own check-ins. Mounted at `/me/post-event-check-ins` in `app.ts`.
 *
 * All three endpoints require a valid bearer token (requireAuth). Phone / email
 * verification gates are intentionally omitted — check-ins are surfaced on app
 * foreground-resume and must not be blocked by verification state.
 *
 * GET  /me/post-event-check-ins            — surface pending check-ins
 * POST /me/post-event-check-ins/:id/acknowledge — acknowledge (no body)
 * POST /me/post-event-check-ins/:id/flag       — flag with safety report
 *
 * IMPORTANT: the acknowledge route has NO zValidator('json', ...) middleware.
 * Mounting a JSON body validator on a no-body POST triggers Hono's
 * c.req.json() path, which throws a 400 "Malformed JSON" when the mobile
 * client sends Content-Type: application/json with an empty body (identical
 * to the TRI-28 regression on join-requests). See the integration test for
 * the regression pin.
 */
export const buildCheckInsRoutes = (
  deps: CheckInsRouteDeps,
): Hono<{ Variables: AuthVariables }> => {
  const auth = requireAuth(deps.accessTokens);

  return new Hono<{ Variables: AuthVariables }>()
    .get('/', auth, (c) => deps.controller.listPendingAction(c, c.get('userId')))
    .post(
      '/:id/acknowledge',
      auth,
      // No zValidator — empty-body POST trap (see module JSDoc).
      (c) => deps.controller.acknowledgeAction(c, c.req.param('id'), c.get('userId')),
    )
    .post('/:id/flag', auth, zValidator('json', flagCheckInBodySchema), (c) =>
      deps.controller.flagAction(c, c.req.param('id'), c.get('userId'), c.req.valid('json')),
    );
};

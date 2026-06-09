import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { optionalJsonValidator } from '@/core/middleware/optional-json-validator.js';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { CheckInsController } from '../controllers/check-ins.controller.js';
import {
  acknowledgeCheckInBodySchema,
  flagCheckInBodySchema,
} from '../schemas/check-ins.schemas.js';

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
 * The acknowledge route uses `optionalJsonValidator(acknowledgeCheckInBodySchema)`
 * rather than `zValidator('json', ...)`. The mobile Dio client always sends
 * Content-Type: application/json with an empty body on no-body POSTs;
 * `zValidator` calls `c.req.json()` before schema validation runs, which
 * throws 400 on an empty body (TRI-28 regression). `optionalJsonValidator`
 * performs a tolerant body read (absent/empty/unparseable → `{}`) before
 * schema validation, so the empty-body tolerance is structural rather than
 * implicit. See the integration test for the regression pin.
 */
export const buildCheckInsRoutes = (
  deps: CheckInsRouteDeps,
): Hono<{ Variables: AuthVariables }> => {
  const auth = requireAuth(deps.accessTokens);

  return new Hono<{ Variables: AuthVariables }>()
    .get('/', auth, (c) => deps.controller.listPendingAction(c, c.get('userId')))
    .post('/:id/acknowledge', auth, optionalJsonValidator(acknowledgeCheckInBodySchema), (c) =>
      deps.controller.acknowledgeAction(c, c.req.param('id'), c.get('userId')),
    )
    .post('/:id/flag', auth, zValidator('json', flagCheckInBodySchema), (c) =>
      deps.controller.flagAction(c, c.req.param('id'), c.get('userId'), c.req.valid('json')),
    );
};

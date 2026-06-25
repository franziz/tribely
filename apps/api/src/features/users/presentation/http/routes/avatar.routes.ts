import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { UserController } from '../controllers/user.controller.js';

export interface AvatarRouteDeps {
  controller: UserController;
  accessTokens: AccessTokenIssuer;
}

const confirmAvatarBodySchema = z.object({
  storageKey: z.string().min(1),
});

/**
 * Avatar upload routes — additive mount under `/users` in `app.ts`.
 *
 * POST /users/me/avatar           — presign: returns { uploadUrl, storageKey }.
 *                                   No request body (avoids Hono empty-body trap).
 * POST /users/me/avatar/confirm   — confirm: { storageKey } → updates User aggregate,
 *                                   best-effort deletes prior avatar, returns UserResponse.
 *
 * Both routes are `requireAuth`-gated. No `requireVerifiedEmail` / `requireVerifiedPhone`
 * guard — avatar upload is a basic profile action available to all authenticated users.
 *
 * Note: the presign route deliberately has NO zValidator('json', ...) —
 * mounting one on a no-body POST triggers the Hono empty-body trap (400 on
 * absent body). See CLAUDE.md gotcha and TRI-28/TRI-34 precedent.
 */
export const buildAvatarRoutes = (deps: AvatarRouteDeps): Hono<{ Variables: AuthVariables }> => {
  const auth = requireAuth(deps.accessTokens);

  return new Hono<{ Variables: AuthVariables }>()
    .post('/me/avatar', auth, (c) => deps.controller.requestAvatarUploadAction(c))
    .post('/me/avatar/confirm', auth, zValidator('json', confirmAvatarBodySchema), (c) =>
      deps.controller.confirmAvatarUploadAction(c, c.req.valid('json').storageKey),
    );
};

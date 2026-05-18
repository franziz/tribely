import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { GetUserUseCase } from '../../../application/usecases/get-user.usecase.js';
import type { GetUserCapabilitiesUseCase } from '../../../application/usecases/get-user-capabilities.usecase.js';
import type { UpdateUserProfileUseCase } from '../../../application/usecases/update-user-profile.usecase.js';
import { UserController } from '../controllers/user.controller.js';
import { updateUserProfileSchema } from '../schemas/user.schemas.js';

export interface UserRouteDeps {
  getUser: GetUserUseCase;
  updateUserProfile: UpdateUserProfileUseCase;
  getUserCapabilities: GetUserCapabilitiesUseCase;
  accessTokens: AccessTokenIssuer;
  clock: Clock;
}

export const buildUserRoutes = (deps: UserRouteDeps): Hono<{ Variables: AuthVariables }> => {
  const controller = new UserController(
    deps.getUser,
    deps.updateUserProfile,
    deps.clock,
    deps.getUserCapabilities,
  );
  const auth = requireAuth(deps.accessTokens);

  return (
    new Hono<{ Variables: AuthVariables }>()
      // /me/* routes MUST come before /:id — Hono v4 is first-registered-wins;
      // registering /:id first would swallow GET /me/capabilities as id="me".
      .patch('/me', auth, zValidator('json', updateUserProfileSchema), (c) =>
        controller.patchMe(c, c.req.valid('json')),
      )
      .get('/me/capabilities', auth, (c) => controller.getMyCapabilities(c))
      .get('/:id', (c) => controller.get(c, c.req.param('id')))
  );
};

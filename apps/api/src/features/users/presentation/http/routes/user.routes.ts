import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import { requireVerifiedEmail } from '@/core/middleware/require-verified-email.js';
import { requireVerifiedPhone } from '@/core/middleware/require-verified-phone.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { GetUserUseCase } from '../../../application/usecases/get-user.usecase.js';
import type { GetUserCapabilitiesUseCase } from '../../../application/usecases/get-user-capabilities.usecase.js';
import type { UpdateUserProfileUseCase } from '../../../application/usecases/update-user-profile.usecase.js';
import type { DeleteAccountUseCase } from '../../../application/usecases/delete-account.usecase.js';
import { UserController } from '../controllers/user.controller.js';
import { updateUserProfileSchema } from '../schemas/user.schemas.js';

/**
 * Extract the caller's userId from a `Bearer` token without throwing.
 * Returns `undefined` when no token is present or the token is invalid.
 * Used by the unauthenticated `GET /users/:id` route to optionally apply
 * viewer-aware block/visibility filtering on the review aggregate.
 */
const tryExtractViewerId = async (
  accessTokens: AccessTokenIssuer,
  authHeader: string | undefined,
): Promise<string | undefined> => {
  if (!authHeader?.startsWith('Bearer ')) return undefined;
  try {
    const subject = await accessTokens.verify(authHeader.slice('Bearer '.length).trim());
    return subject.userId;
  } catch {
    return undefined;
  }
};

export interface UserRouteDeps {
  getUser: GetUserUseCase;
  updateUserProfile: UpdateUserProfileUseCase;
  getUserCapabilities: GetUserCapabilitiesUseCase;
  deleteAccount: DeleteAccountUseCase;
  accessTokens: AccessTokenIssuer;
  clock: Clock;
  userRepository: UserRepository;
}

export const buildUserRoutes = (deps: UserRouteDeps): Hono<{ Variables: AuthVariables }> => {
  const controller = new UserController(
    deps.getUser,
    deps.updateUserProfile,
    deps.clock,
    deps.getUserCapabilities,
    deps.deleteAccount,
  );
  const auth = requireAuth(deps.accessTokens);
  const verifiedEmail = requireVerifiedEmail(deps.userRepository);
  const verifiedPhone = requireVerifiedPhone(deps.userRepository);

  return (
    new Hono<{ Variables: AuthVariables }>()
      // /me/* and DELETE /me routes MUST come before /:id — Hono v4 is
      // first-registered-wins; registering /:id first would swallow these as id="me".
      .delete('/me', auth, (c) => controller.deleteMe(c))
      .patch(
        '/me',
        auth,
        verifiedEmail,
        verifiedPhone,
        zValidator('json', updateUserProfileSchema),
        (c) => controller.patchMe(c, c.req.valid('json')),
      )
      .get('/me/capabilities', auth, (c) => controller.getMyCapabilities(c))
      .get('/:id', async (c) => {
        const viewerId = await tryExtractViewerId(deps.accessTokens, c.req.header('Authorization'));
        return controller.get(c, c.req.param('id'), viewerId);
      })
  );
};

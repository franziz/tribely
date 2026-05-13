import { Hono } from 'hono';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import { requireVerifiedEmail } from '@/core/middleware/require-verified-email.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { EventController } from '../controllers/event.controller.js';

export interface MyEventRouteDeps {
  controller: EventController;
  accessTokens: AccessTokenIssuer;
  userRepository: UserRepository;
}

/**
 * Routes scoped to the authenticated user's own hosted events.
 * Mounted at `/me` in `app.ts`.
 *
 * `GET /me/events` — paginated list of events the caller hosts.
 * Returns the same shape as `GET /events` (EventListingResponse).
 *
 * Auth requirements: `requireAuth + requireVerifiedEmail`.
 * The `hostUserId=me` sentinel on `GET /events` is retired — callers
 * that want their own events must use this route.
 */
export const buildMyEventRoutes = (deps: MyEventRouteDeps): Hono<{ Variables: AuthVariables }> => {
  const auth = requireAuth(deps.accessTokens);
  const verified = requireVerifiedEmail(deps.userRepository);

  return new Hono<{ Variables: AuthVariables }>().get('/events', auth, verified, (c) =>
    deps.controller.listMyEventsAction(c, c.get('userId')),
  );
};

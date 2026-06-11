import { Hono, type Context } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { rateLimit } from '@/core/middleware/rate-limit.js';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import { requireVerifiedEmail } from '@/core/middleware/require-verified-email.js';
import { requireVerifiedPhone } from '@/core/middleware/require-verified-phone.js';
import { requireVerifiedSelfie } from '@/core/middleware/require-verified-selfie.js';
import type { RateLimiter } from '@/core/security/rate-limiter.port.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { EventController } from '../controllers/event.controller.js';
import {
  cancelEventBodySchema,
  createEventBodySchema,
  listEventsQuerySchema,
  updateEventBodySchema,
} from '../schemas/event.schemas.js';

export interface EventRouteDeps {
  controller: EventController;
  accessTokens: AccessTokenIssuer;
  rateLimiter: RateLimiter;
  userRepository: UserRepository;
}

export const buildEventRoutes = (deps: EventRouteDeps): Hono<{ Variables: AuthVariables }> => {
  const { controller } = deps;
  const auth = requireAuth(deps.accessTokens);
  const verifiedEmail = requireVerifiedEmail(deps.userRepository);
  const verifiedPhone = requireVerifiedPhone(deps.userRepository);
  const verifiedSelfie = requireVerifiedSelfie(deps.userRepository);

  // Per the AC: 5 creates per hour per user. Per-user (not per-IP) because the
  // event-create action is meaningful only after auth, and we want the cap to
  // follow the actor across networks.
  const userKey = (c: Context): string =>
    (c as Context<{ Variables: AuthVariables }>).get('userId');
  const limitCreate = rateLimit(deps.rateLimiter, {
    bucket: 'events-create',
    limit: 5,
    windowSeconds: 60 * 60,
    keyFor: userKey,
  });

  return new Hono<{ Variables: AuthVariables }>()
    .post(
      '/',
      auth,
      verifiedEmail,
      verifiedPhone,
      verifiedSelfie,
      limitCreate,
      zValidator('json', createEventBodySchema),
      (c) => controller.createAction(c, c.get('userId'), c.req.valid('json')),
    )
    .get('/', zValidator('query', listEventsQuerySchema), (c) =>
      controller.listAction(c, c.req.valid('query')),
    )
    .get('/:id', (c) => controller.getAction(c, c.req.param('id')))
    .patch(
      '/:id',
      auth,
      verifiedEmail,
      verifiedPhone,
      verifiedSelfie,
      zValidator('json', updateEventBodySchema),
      (c) => controller.updateAction(c, c.req.param('id'), c.get('userId'), c.req.valid('json')),
    )
    .delete(
      '/:id',
      auth,
      verifiedEmail,
      verifiedPhone,
      verifiedSelfie,
      zValidator('json', cancelEventBodySchema),
      (c) => controller.cancelAction(c, c.req.param('id'), c.get('userId'), c.req.valid('json')),
    );
};

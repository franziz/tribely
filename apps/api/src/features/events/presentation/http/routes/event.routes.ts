import { Hono, type Context } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { rateLimit } from '@/core/middleware/rate-limit.js';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import type { RateLimiter } from '@/core/security/rate-limiter.port.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { CancelEventUseCase } from '../../../application/usecases/cancel-event.usecase.js';
import type { CreateEventUseCase } from '../../../application/usecases/create-event.usecase.js';
import type { GetEventUseCase } from '../../../application/usecases/get-event.usecase.js';
import type { ListEventsUseCase } from '../../../application/usecases/list-events.usecase.js';
import type { UpdateEventUseCase } from '../../../application/usecases/update-event.usecase.js';
import { EventController } from '../controllers/event.controller.js';
import {
  cancelEventBodySchema,
  createEventBodySchema,
  listEventsQuerySchema,
  updateEventBodySchema,
} from '../schemas/event.schemas.js';

export interface EventRouteDeps {
  createEvent: CreateEventUseCase;
  listEvents: ListEventsUseCase;
  getEvent: GetEventUseCase;
  updateEvent: UpdateEventUseCase;
  cancelEvent: CancelEventUseCase;
  accessTokens: AccessTokenIssuer;
  rateLimiter: RateLimiter;
}

export const buildEventRoutes = (deps: EventRouteDeps): Hono<{ Variables: AuthVariables }> => {
  const controller = new EventController(
    deps.createEvent,
    deps.listEvents,
    deps.getEvent,
    deps.updateEvent,
    deps.cancelEvent,
  );
  const auth = requireAuth(deps.accessTokens);

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
    .post('/', auth, limitCreate, zValidator('json', createEventBodySchema), (c) =>
      controller.createAction(c, c.get('userId'), c.req.valid('json')),
    )
    .get('/', zValidator('query', listEventsQuerySchema), (c) =>
      controller.listAction(c, c.req.valid('query')),
    )
    .get('/:id', (c) => controller.getAction(c, c.req.param('id')))
    .patch('/:id', auth, zValidator('json', updateEventBodySchema), (c) =>
      controller.updateAction(c, c.req.param('id'), c.get('userId'), c.req.valid('json')),
    )
    .delete('/:id', auth, zValidator('json', cancelEventBodySchema), (c) =>
      controller.cancelAction(c, c.req.param('id'), c.get('userId'), c.req.valid('json')),
    );
};

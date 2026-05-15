import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger as honoLogger } from 'hono/logger';
import { buildContainer, type Container } from './core/di/container.js';
import { errorHandler } from './core/middleware/error-handler.js';
import { requestContext } from './core/middleware/request-context.js';
import { auditHttp } from './features/audit/presentation/middleware/audit-http.js';
import { buildAuthRoutes } from './features/auth/presentation/http/routes/auth.routes.js';
import { EventController } from './features/events/presentation/http/controllers/event.controller.js';
import { buildEventRoutes } from './features/events/presentation/http/routes/event.routes.js';
import { buildMyEventRoutes } from './features/events/presentation/http/routes/my-event.routes.js';
import { JoinRequestController } from './features/join-requests/presentation/http/controllers/join-request.controller.js';
import { buildEventScopedJoinRequestRoutes } from './features/join-requests/presentation/http/routes/event-scoped-join-request.routes.js';
import { buildJoinRequestRoutes } from './features/join-requests/presentation/http/routes/join-request.routes.js';
import { buildMyJoinRequestsRoutes } from './features/join-requests/presentation/http/routes/my-join-request.routes.js';
import { buildUserRoutes } from './features/users/presentation/http/routes/user.routes.js';

export const buildApp = (): { app: Hono; container: Container } => {
  const container = buildContainer();
  const app = new Hono();

  app.use('*', cors());
  // Open the AsyncLocalStorage frame BEFORE any code that might publish
  // domain events. Routes / requireAuth / publisher / dispatcher all read
  // it via getRequestContext().
  app.use('*', requestContext());
  // auditHttp records the request *after* `next()` returns — so it sees
  // the final response status (including statuses set by errorHandler when
  // an exception was thrown). Must be after requestContext.
  app.use('*', auditHttp(container.recordHttpCallUseCase));
  app.use('*', honoLogger());

  app.get('/health', (c) => c.json({ status: 'ok' }));

  app.route(
    '/auth',
    buildAuthRoutes({
      signUp: container.signUpUseCase,
      signIn: container.signInUseCase,
      refresh: container.refreshTokensUseCase,
      signOut: container.signOutUseCase,
      signOutAll: container.signOutAllUseCase,
      getUser: container.getUserUseCase,
      verifyEmail: container.verifyEmailUseCase,
      resendVerification: container.resendEmailVerificationUseCase,
      requestPasswordReset: container.requestPasswordResetUseCase,
      resetPassword: container.resetPasswordUseCase,
      accessTokens: container.accessTokens,
      rateLimiter: container.rateLimiter,
    }),
  );
  app.route(
    '/users',
    buildUserRoutes({
      getUser: container.getUserUseCase,
      updateUserProfile: container.updateUserProfileUseCase,
      getUserCapabilities: container.getUserCapabilitiesUseCase,
      accessTokens: container.accessTokens,
      clock: container.clock,
    }),
  );
  const eventController = new EventController(
    container.createEventUseCase,
    container.listEventsUseCase,
    container.getEventUseCase,
    container.updateEventUseCase,
    container.cancelEventUseCase,
  );
  app.route(
    '/events',
    buildEventRoutes({
      controller: eventController,
      accessTokens: container.accessTokens,
      rateLimiter: container.rateLimiter,
    }),
  );
  // GET /me/events — authenticated user's own hosted events.
  // Mirrors the /me/join-requests pattern (MyJoinRequestRoutes).
  app.route(
    '/me',
    buildMyEventRoutes({
      controller: eventController,
      accessTokens: container.accessTokens,
      userRepository: container.userRepository,
    }),
  );

  // Join requests: one controller, three routers, three mount points.
  //   /events/:id/join-requests       — discovering/listing under the parent
  //   /join-requests/:id/{approve,reject} + DELETE — operating on a single row
  //   /me/join-requests               — requester's own join requests
  // Hono's app.route() is additive — multiple mounts at `/events` merge into
  // the parent router's tree. The event router owns `/events`, `/events/:id`;
  // this router owns `/events/:id/join-requests` — non-overlapping paths.
  const joinRequestController = new JoinRequestController(
    container.requestToJoinEventUseCase,
    container.approveJoinRequestUseCase,
    container.rejectJoinRequestUseCase,
    container.cancelJoinRequestByRequesterUseCase,
    container.listJoinRequestsByEventUseCase,
    container.listJoinRequestsByRequesterUseCase,
  );
  app.route(
    '/events',
    buildEventScopedJoinRequestRoutes({
      controller: joinRequestController,
      accessTokens: container.accessTokens,
      userRepository: container.userRepository,
      rateLimiter: container.rateLimiter,
    }),
  );
  app.route(
    '/join-requests',
    buildJoinRequestRoutes({
      controller: joinRequestController,
      accessTokens: container.accessTokens,
      userRepository: container.userRepository,
    }),
  );
  app.route(
    '/me',
    buildMyJoinRequestsRoutes({
      controller: joinRequestController,
      accessTokens: container.accessTokens,
      userRepository: container.userRepository,
    }),
  );

  app.onError(errorHandler);
  app.notFound((c) => c.json({ error: { code: 'NOT_FOUND', message: 'Route not found' } }, 404));

  return { app, container };
};

export type AppType = ReturnType<typeof buildApp>['app'];

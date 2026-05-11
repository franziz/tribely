import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger as honoLogger } from 'hono/logger';
import { buildContainer, type Container } from './core/di/container.js';
import { errorHandler } from './core/middleware/error-handler.js';
import { requestContext } from './core/middleware/request-context.js';
import { auditHttp } from './features/audit/presentation/middleware/audit-http.js';
import { buildAuthRoutes } from './features/auth/presentation/http/routes/auth.routes.js';
import { buildEventRoutes } from './features/events/presentation/http/routes/event.routes.js';
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
  app.route('/users', buildUserRoutes({ getUser: container.getUserUseCase }));
  app.route(
    '/events',
    buildEventRoutes({
      createEvent: container.createEventUseCase,
      listEvents: container.listEventsUseCase,
      getEvent: container.getEventUseCase,
      updateEvent: container.updateEventUseCase,
      cancelEvent: container.cancelEventUseCase,
      accessTokens: container.accessTokens,
      rateLimiter: container.rateLimiter,
    }),
  );

  app.onError(errorHandler);
  app.notFound((c) => c.json({ error: { code: 'NOT_FOUND', message: 'Route not found' } }, 404));

  return { app, container };
};

export type AppType = ReturnType<typeof buildApp>['app'];

import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger as honoLogger } from 'hono/logger';
import { buildContainer, type Container } from './core/di/container.js';
import { errorHandler } from './core/middleware/error-handler.js';
import { requestContext } from './core/middleware/request-context.js';
import { buildAuthRoutes } from './features/auth/presentation/http/routes/auth.routes.js';
import { buildUserRoutes } from './features/users/presentation/http/routes/user.routes.js';

export const buildApp = (): { app: Hono; container: Container } => {
  const container = buildContainer();
  const app = new Hono();

  app.use('*', cors());
  // Open the AsyncLocalStorage frame BEFORE any code that might publish
  // domain events. Routes / requireAuth / publisher / dispatcher all read
  // it via getRequestContext().
  app.use('*', requestContext());
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
      accessTokens: container.accessTokens,
      rateLimiter: container.rateLimiter,
    }),
  );
  app.route('/users', buildUserRoutes({ getUser: container.getUserUseCase }));

  app.onError(errorHandler);
  app.notFound((c) => c.json({ error: { code: 'NOT_FOUND', message: 'Route not found' } }, 404));

  return { app, container };
};

export type AppType = ReturnType<typeof buildApp>['app'];

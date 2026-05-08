import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger as honoLogger } from 'hono/logger';
import { buildContainer } from './core/di/container.js';
import { errorHandler } from './core/middleware/error-handler.js';
import { buildAuthRoutes } from './features/auth/presentation/routes/auth.routes.js';

export const buildApp = () => {
  const container = buildContainer();
  const app = new Hono();

  app.use('*', cors());
  app.use('*', honoLogger());

  app.get('/health', (c) => c.json({ status: 'ok' }));

  app.route('/auth', buildAuthRoutes(container));

  app.onError(errorHandler);
  app.notFound((c) => c.json({ error: { code: 'NOT_FOUND', message: 'Route not found' } }, 404));

  return app;
};

export type AppType = ReturnType<typeof buildApp>;

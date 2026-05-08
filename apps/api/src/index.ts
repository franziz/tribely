import { serve } from '@hono/node-server';
import { buildApp } from './app.js';
import { env } from './core/config/env.js';
import { logger } from './core/middleware/logger.js';

const app = buildApp();

serve({ fetch: app.fetch, port: env.PORT }, (info) => {
  logger.info({ port: info.port, env: env.NODE_ENV }, 'API listening');
});

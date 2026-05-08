import { serve } from '@hono/node-server';
import { buildApp } from './app.js';
import { env } from './core/config/env.js';
import { logger } from './core/middleware/logger.js';

const { app, container } = buildApp();

container.dispatcher.start();

const server = serve({ fetch: app.fetch, port: env.PORT }, (info) => {
  logger.info({ port: info.port, env: env.NODE_ENV }, 'API listening');
});

const shutdown = async (signal: string): Promise<void> => {
  logger.info({ signal }, 'Shutting down');
  await container.dispatcher.stop();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10_000).unref();
};

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));

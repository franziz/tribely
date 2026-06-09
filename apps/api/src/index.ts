import { serve } from '@hono/node-server';
import { buildApp } from './app.js';
import { env } from './core/config/env.js';
import { logger } from './core/middleware/logger.js';
import { S3FileStorageAdapter } from './core/storage/s3-file-storage.js';
import { runAsSystem } from './core/context/system-context.js';
import { initSentry } from './core/observability/sentry.js';

async function main(): Promise<void> {
  // Sentry must be initialised before any other module that might throw, so
  // that all subsequent errors — including errors inside buildApp() — are
  // captured. No-ops when SENTRY_DSN is absent.
  initSentry();

  const { app, container } = buildApp();

  if (env.NODE_ENV === 'production' && env.STORAGE_TRANSPORT === 's3') {
    // Boot-time reachability gate: the only place in the codebase that
    // legitimately holds concrete-type knowledge of S3FileStorageAdapter.
    // verifyReachable() is adapter-specific and intentionally absent from
    // the FileStorage port — fail-fast here rather than silently accepting
    // a mis-configured bucket at startup and discovering it at request time.
    if (container.fileStorage instanceof S3FileStorageAdapter) {
      await container.fileStorage.verifyReachable();
    }
  }

  if (env.ADMIN_BOOTSTRAP_EMAIL) {
    const bootstrapEmail = env.ADMIN_BOOTSTRAP_EMAIL;
    await runAsSystem('boot.admin-bootstrap', async () => {
      const result = await container.promoteAdminOnBoot.execute({ email: bootstrapEmail });
      if (result.outcome === 'promoted') {
        logger.warn(
          { userId: result.userId, email: result.email },
          'admin bootstrap: promoted user to admin',
        );
      } else {
        logger.info({ outcome: result.outcome }, 'admin bootstrap: no-op');
      }
    });
  }

  container.dispatcher.start();
  container.pruneSelfieDeletionEventsJob.start();
  container.sweepRetainedSelfiesJob.start();
  container.sweepResolvedReportsJob.start();

  const server = serve({ fetch: app.fetch, port: env.PORT }, (info) => {
    logger.info({ port: info.port, env: env.NODE_ENV }, 'API listening');
  });

  const shutdown = async (signal: string): Promise<void> => {
    logger.info({ signal }, 'Shutting down');
    // Stop jobs in reverse-start order, all before the dispatcher — jobs have
    // no outbound dependency on the dispatcher, and stopping first avoids the
    // (unlikely but possible) race where a tick fires after the dispatcher has
    // already torn down its DB connection.
    await container.sweepResolvedReportsJob.stop();
    await container.sweepRetainedSelfiesJob.stop();
    await container.pruneSelfieDeletionEventsJob.stop();
    await container.dispatcher.stop();
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10_000).unref();
  };

  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));
}

main().catch((err: unknown) => {
  logger.fatal({ err }, 'API failed to boot');
  process.exit(1);
});

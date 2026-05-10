import { createId } from '@paralleldrive/cuid2';
import { runWithContext, type RequestContext } from './request-context.js';

/**
 * Typed escape hatch for non-HTTP callers that publish events: boot-time
 * seeders, future cron jobs, CLI scripts. Without this wrapper such callers
 * publish to the outbox with `requestId = null`, which silently rots the
 * audit chain.
 *
 * Convention: the `label` is the audit-visible identity of the system actor
 * — choose stable, dot-namespaced names like `boot.outbox-dispatcher`,
 * `cron.prune-refresh-tokens`, `cli.seed-events`. The label is embedded into
 * the synthetic `requestId` so audit reads can filter `WHERE requestId LIKE
 * 'system:boot.%'`.
 *
 * Usage:
 *   await runAsSystem('boot.dispatcher-warmup', async () => {
 *     await someUseCase.execute(...);
 *   });
 */
export const runAsSystem = <T>(label: string, fn: () => Promise<T> | T): Promise<T> | T => {
  const ctx: RequestContext = {
    requestId: `system:${label}:${createId()}`,
    actorUserId: null,
  };
  return runWithContext(ctx, fn);
};

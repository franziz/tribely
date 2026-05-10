import { AsyncLocalStorage } from 'node:async_hooks';

/**
 * Request-scoped context that flows through every async boundary inside a
 * single HTTP request — middleware → use case → repository → publisher.
 *
 * Production scenarios that read it:
 *   - `OutboxEventPublisher` persists `requestId` + `actorUserId` onto each
 *     outbox row so the dispatcher can later re-establish the same context
 *     for downstream consumers.
 *   - `audit-http` middleware reads `requestId` + `actorUserId` to record
 *     the HTTP audit row.
 *   - `pino` child loggers attached to the context emit log lines tagged
 *     with `requestId` for cross-line correlation.
 *
 * Why AsyncLocalStorage and not "thread `meta` through every function":
 *   - Use case signatures stay clean (`execute(input)` not `execute(input, meta)`).
 *   - Cross-cutting concerns (audit, observability) get the data they need
 *     without each layer being aware of them. This is the pattern OpenTelemetry
 *     uses for trace context propagation.
 *
 * Trade-off: ALS is invisible state, easy to lose across the outbox boundary.
 * Mitigated by:
 *   - Persisting context onto the outbox row at publish time.
 *   - `runWithContext` re-establishing the frame at dispatch time.
 *   - `runAsSystem` (system-context.ts) as the typed escape hatch for
 *     non-HTTP entry points (boot, future cron jobs, CLI).
 */
export interface RequestContext {
  readonly requestId: string;
  readonly actorUserId: string | null;
}

const storage = new AsyncLocalStorage<RequestContext>();

export const runWithContext = <T>(
  context: RequestContext,
  fn: () => Promise<T> | T,
): Promise<T> | T => storage.run(context, fn);

/**
 * Returns the current request context, or null if called outside any
 * `runWithContext` / `runAsSystem` frame. Callers should treat null as
 * "this happened outside an HTTP request" — typically a boot path that
 * should have been wrapped in `runAsSystem`.
 */
export const getRequestContext = (): RequestContext | null => storage.getStore() ?? null;

/**
 * Replace just the `actorUserId` on the current frame. Used by `requireAuth`
 * after JWT verification to upgrade an anonymous request frame (created by
 * the request-context middleware before auth runs) into an authenticated one.
 *
 * Implemented by re-running with a new context — ALS frames are immutable
 * once created. Caller hands us the continuation.
 */
export const upgradeActorUserId = <T>(
  actorUserId: string,
  fn: () => Promise<T> | T,
): Promise<T> | T => {
  const current = storage.getStore();
  if (!current) {
    throw new Error(
      'upgradeActorUserId called outside a request context — wrap in runWithContext or runAsSystem first',
    );
  }
  return storage.run({ ...current, actorUserId }, fn);
};

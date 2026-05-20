import type { ConsumerRegistry } from '@/core/events/consumer-registry.js';

/**
 * Register every consumer the `reports` feature owns. Add Consumer objects
 * via `registry.register(...)` here. Other features that care about
 * reports' events register their consumers from their own
 * presentation/events/index.ts — not here.
 */
export const registerReportsConsumers = (_registry: ConsumerRegistry): void => {
  // registry.register(somethingOnReportFiled({ /* deps */ }));
};

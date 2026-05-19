#!/usr/bin/env tsx
// Manual run of the selfie retention sweep.
// Use for investigating, recovering missed ticks, or verifying deploy wiring.
//
// Usage:
//   npm run --workspace=@tribely/api sweep:selfies

import { buildContainer } from '@/core/di/container.js';
import { runAsSystem } from '@/core/context/system-context.js';

async function main(): Promise<void> {
  const container = buildContainer();
  const result = await runAsSystem('cli.sweep-selfies', async () => {
    return container.sweepRetainedSelfiesUseCase.execute();
  });
  console.log(JSON.stringify(result, null, 2));
  process.exit(0);
}

main().catch((err) => {
  console.error('sweep:selfies failed:', err);
  process.exit(1);
});

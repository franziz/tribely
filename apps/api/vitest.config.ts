import tsconfigPaths from 'vite-tsconfig-paths';
import { defineConfig } from 'vitest/config';

// `tsconfigPaths` wires the `@/*` alias from tsconfig.json into Vitest's
// resolver — required everywhere because source files use `@/` heavily.
//
// Projects split: unit tests are pure (no DB, fast); integration tests live
// in `*.integration.test.ts` files and require DATABASE_URL pointed at a real
// Postgres. CI runs both; locally `npm run test:unit` stays fast for the
// inner loop.
export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    projects: [
      {
        extends: true,
        test: {
          name: 'unit',
          include: ['src/**/*.test.ts'],
          exclude: ['src/**/*.integration.test.ts', 'node_modules/**'],
        },
      },
      {
        extends: true,
        test: {
          name: 'integration',
          include: ['src/**/*.integration.test.ts'],
          fileParallelism: false,
        },
      },
    ],
  },
});

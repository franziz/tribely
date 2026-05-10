import tsconfigPaths from 'vite-tsconfig-paths';
import { defineConfig } from 'vitest/config';

// Wires the `@/*` path alias from tsconfig.json into Vitest's Vite resolver.
// Source files use `@/` heavily (49+ files); without this plugin, any test
// that transitively imports a `@/`-using file fails at resolution time.
export default defineConfig({
  plugins: [tsconfigPaths()],
});

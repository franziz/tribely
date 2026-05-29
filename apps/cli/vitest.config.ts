import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['src/**/*.test.ts'],
    // Passes cleanly until Brief 2/3 land test files.
    passWithNoTests: true,
  },
});

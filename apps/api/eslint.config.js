// @ts-check
import js from '@eslint/js';
import tseslint from 'typescript-eslint';

/**
 * `tseslint.configs.strictTypeChecked` enables type-aware rules that catch
 * real runtime bugs (no-floating-promises, no-misused-promises, no-unsafe-*).
 * Requires `parserOptions.projectService: true` to read tsconfig.json.
 *
 * If Hono's middleware patterns trigger no-unsafe-* findings, the fix is
 * tighter Hono type generics (Bindings/Variables) — NOT a weaker eslint
 * config. Compromise the code, not the standards.
 *
 * Prettier handles formatting; eslint stays focused on correctness.
 */
export default tseslint.config(
  {
    ignores: [
      'dist/**',
      'node_modules/**',
      'prisma/migrations/**',
      'coverage/**',
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  {
    files: ['src/**/*.ts'],
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      '@typescript-eslint/no-explicit-any': 'warn',
      // Allow void-returning callbacks (Hono middleware shape).
      '@typescript-eslint/no-misused-promises': [
        'error',
        { checksVoidReturn: { arguments: false, attributes: false } },
      ],
    },
  },
  {
    files: ['src/**/*.test.ts', 'src/**/*.spec.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-unsafe-assignment': 'off',
      '@typescript-eslint/no-unsafe-member-access': 'off',
      '@typescript-eslint/no-unsafe-call': 'off',
    },
  },
);

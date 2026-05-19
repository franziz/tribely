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
  // Enforce the Twilio SDK import boundary. The `twilio` package must only be
  // imported from the adapter and its opt-in integration test. The unit test
  // file is intentionally NOT in the allowlist — it uses plain object stubs
  // (duck-typed wire shape) and must not re-introduce a real SDK import.
  // Any violation is caught at lint time, before CI tests run.
  {
    files: ['src/**/*.ts'],
    ignores: [
      'src/core/sms/twilio-phone-verifier.ts',
      'src/core/sms/__test__/twilio-phone-verifier.integration.test.ts',
    ],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          paths: [
            {
              name: 'twilio',
              message:
                "Import the 'twilio' SDK only from core/sms/twilio-phone-verifier.ts. " +
                'Consume the PhoneVerifier port (core/sms/phone-verifier.port.ts) elsewhere.',
            },
          ],
        },
      ],
    },
  },
  // Enforce the AWS SDK import boundary. `@aws-sdk/client-s3` and
  // `@aws-sdk/s3-request-presigner` must only be imported from the S3 adapter
  // and its opt-in integration test. All other callers must consume the
  // FileStorage port instead. Any violation is caught at lint time.
  {
    files: ['src/**/*.ts'],
    ignores: [
      'src/core/storage/s3-file-storage.ts',
      'src/core/storage/s3-file-storage.integration.test.ts',
    ],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: ['@aws-sdk/*'],
              message:
                'Import @aws-sdk/* only from core/storage/s3-file-storage.ts. ' +
                'All other files must consume the FileStorage port instead.',
            },
          ],
        },
      ],
    },
  },
);

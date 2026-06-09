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
  // SDK import boundary — base floor (all three restrictions active for every src file).
  //
  // Enforce the Twilio SDK import boundary. The `twilio` package must only be
  // imported from the adapter and its opt-in integration test. The unit test
  // file is intentionally NOT in the allowlist — it uses plain object stubs
  // (duck-typed wire shape) and must not re-introduce a real SDK import.
  //
  // Enforce the AWS SDK import boundary. `@aws-sdk/client-s3` and
  // `@aws-sdk/s3-request-presigner` must only be imported from the S3 adapter
  // and its opt-in integration test. All other callers must consume the
  // FileStorage port instead.
  //
  // Enforce the Sentry SDK import boundary. `@sentry/node` must only be
  // imported from the Sentry observability module and its unit test.
  // All other files must consume the helpers (initSentry, captureAppError,
  // captureUnhandled) from core/observability/sentry.ts instead.
  //
  // All violations are caught at lint time, before CI tests run.
  //
  // ESLint flat-config merges: multiple objects with the same `files` glob and
  // the same rule key are NOT additive — the last object's options REPLACE
  // earlier ones. To keep all three boundaries simultaneously active, the base
  // floor lists all three SDKs in a single `no-restricted-imports` declaration.
  // Narrow per-adapter override objects below (scoped by `files:`, not
  // `ignores:`) re-declare the rule omitting only that adapter's own SDK,
  // leaving the other two boundaries enforced even on the adapter file itself.
  {
    files: ['src/**/*.ts'],
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
            {
              name: '@sentry/node',
              message:
                "Import '@sentry/node' only from core/observability/sentry.ts. " +
                'Consume the helpers (initSentry, captureAppError, captureUnhandled) elsewhere.',
            },
          ],
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
  // Twilio adapter override — omits the `twilio` restriction so the adapter
  // and its opt-in integration test may import the SDK directly. The other two
  // boundaries (@aws-sdk/*, @sentry/node) remain enforced on these files.
  {
    files: [
      'src/core/sms/twilio-phone-verifier.ts',
      'src/core/sms/__test__/twilio-phone-verifier.integration.test.ts',
    ],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          paths: [
            {
              name: '@sentry/node',
              message:
                "Import '@sentry/node' only from core/observability/sentry.ts. " +
                'Consume the helpers (initSentry, captureAppError, captureUnhandled) elsewhere.',
            },
          ],
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
  // S3 adapter override — omits the `@aws-sdk/*` restriction so the adapter
  // and its opt-in integration test may import AWS SDK packages directly. The
  // other two boundaries (twilio, @sentry/node) remain enforced on these files.
  {
    files: [
      'src/core/storage/s3-file-storage.ts',
      'src/core/storage/s3-file-storage.integration.test.ts',
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
            {
              name: '@sentry/node',
              message:
                "Import '@sentry/node' only from core/observability/sentry.ts. " +
                'Consume the helpers (initSentry, captureAppError, captureUnhandled) elsewhere.',
            },
          ],
        },
      ],
    },
  },
  // Sentry adapter override — omits the `@sentry/node` restriction so the
  // adapter and its unit test may import the SDK directly. The other two
  // boundaries (twilio, @aws-sdk/*) remain enforced on these files.
  {
    files: [
      'src/core/observability/sentry.ts',
      'src/core/observability/sentry.test.ts',
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

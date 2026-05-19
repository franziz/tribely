/**
 * Unit tests for env.ts schema validation.
 *
 * We call `envSchema.parse(...)` with synthetic inputs rather than reading the
 * already-parsed `env` singleton — the singleton reflects process.env at module
 * load time and cannot be varied per-test without mutation hacks.
 *
 * Importing `envSchema` triggers `import 'dotenv/config'` and the module-level
 * `envSchema.parse(process.env)` (the `env` singleton). That's identical
 * behavior to every other test that transitively imports from env.ts — safe as
 * long as the test runner environment provides the required vars (DATABASE_URL,
 * JWT_SECRET), which both local .env and CI _api.yml do.
 */
import { describe, expect, it } from 'vitest';
import { envSchema } from './env.js';

// Minimal valid env fixture — all required fields with the smallest legal values.
const validBaseEnv: Record<string, string> = {
  NODE_ENV: 'development',
  DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/tribely_test',
  JWT_SECRET: 'ci-placeholder-secret-must-be-at-least-32-chars',
};

function parseEnv(overrides: Record<string, string>) {
  return envSchema.parse({ ...validBaseEnv, ...overrides });
}

describe('env schema', () => {
  describe('valid configurations', () => {
    it('accepts a minimal development env', () => {
      expect(() => parseEnv({})).not.toThrow();
    });

    it('accepts SMS_TRANSPORT=log in development', () => {
      expect(() => parseEnv({ NODE_ENV: 'development', SMS_TRANSPORT: 'log' })).not.toThrow();
    });

    it('accepts EMAIL_TRANSPORT=log in development', () => {
      expect(() => parseEnv({ NODE_ENV: 'development', EMAIL_TRANSPORT: 'log' })).not.toThrow();
    });

    it('accepts SMS_TRANSPORT=log in test', () => {
      expect(() => parseEnv({ NODE_ENV: 'test', SMS_TRANSPORT: 'log' })).not.toThrow();
    });

    it('accepts EMAIL_TRANSPORT=log in test', () => {
      expect(() => parseEnv({ NODE_ENV: 'test', EMAIL_TRANSPORT: 'log' })).not.toThrow();
    });

    it('accepts SMS_TRANSPORT=twilio in production when all Twilio vars are set', () => {
      expect(() =>
        parseEnv({
          NODE_ENV: 'production',
          SMS_TRANSPORT: 'twilio',
          TWILIO_ACCOUNT_SID: 'ACtest',
          TWILIO_AUTH_TOKEN: 'authtest',
          TWILIO_VERIFY_SERVICE_SID: 'VAtest',
          // Must also provide a real email transport to avoid the email guard.
          EMAIL_TRANSPORT: 'resend',
          RESEND_API_KEY: 'retest',
          // Must also provide a real storage transport to avoid the storage guard.
          STORAGE_TRANSPORT: 's3',
          STORAGE_BUCKET: 'tribely-prod',
          STORAGE_REGION: 'ap-southeast-1',
          STORAGE_ACCESS_KEY_ID: 'AKIATEST',
          STORAGE_SECRET_ACCESS_KEY: 'secrettest',
        }),
      ).not.toThrow();
    });
  });

  describe('production transport guards', () => {
    it('refuses SMS_TRANSPORT=log when NODE_ENV=production', () => {
      expect(() =>
        parseEnv({
          NODE_ENV: 'production',
          SMS_TRANSPORT: 'log',
          // Satisfy email guard so the SMS guard is the only issue.
          EMAIL_TRANSPORT: 'resend',
          RESEND_API_KEY: 'retest',
        }),
      ).toThrow(/SMS_TRANSPORT=log is not allowed when NODE_ENV=production/);
    });

    it('refuses EMAIL_TRANSPORT=log when NODE_ENV=production', () => {
      expect(() =>
        parseEnv({
          NODE_ENV: 'production',
          EMAIL_TRANSPORT: 'log',
          // Satisfy SMS guard so the email guard is the only issue.
          SMS_TRANSPORT: 'twilio',
          TWILIO_ACCOUNT_SID: 'ACtest',
          TWILIO_AUTH_TOKEN: 'authtest',
          TWILIO_VERIFY_SERVICE_SID: 'VAtest',
        }),
      ).toThrow(/EMAIL_TRANSPORT=log is not allowed when NODE_ENV=production/);
    });
  });

  describe('credential requirements', () => {
    it('requires RESEND_API_KEY when EMAIL_TRANSPORT=resend', () => {
      expect(() => parseEnv({ EMAIL_TRANSPORT: 'resend' })).toThrow(
        /RESEND_API_KEY is required when EMAIL_TRANSPORT=resend/,
      );
    });

    it('requires TWILIO_ACCOUNT_SID when SMS_TRANSPORT=twilio', () => {
      expect(() =>
        parseEnv({
          SMS_TRANSPORT: 'twilio',
          TWILIO_AUTH_TOKEN: 'authtest',
          TWILIO_VERIFY_SERVICE_SID: 'VAtest',
        }),
      ).toThrow(/TWILIO_ACCOUNT_SID is required when SMS_TRANSPORT=twilio/);
    });
  });
});

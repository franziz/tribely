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
import { envSchema, optionalString } from './env.js';

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
          // Must also provide PHONE_HASH_SALT to avoid the phone-hasher guard.
          PHONE_HASH_SALT: 'production-phone-hash-salt-00000000',
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

  describe('phone hasher production guard', () => {
    it('refuses a missing PHONE_HASH_SALT when NODE_ENV=production', () => {
      expect(() =>
        parseEnv({
          NODE_ENV: 'production',
          SMS_TRANSPORT: 'twilio',
          TWILIO_ACCOUNT_SID: 'ACtest',
          TWILIO_AUTH_TOKEN: 'authtest',
          TWILIO_VERIFY_SERVICE_SID: 'VAtest',
          EMAIL_TRANSPORT: 'resend',
          RESEND_API_KEY: 'retest',
          // No PHONE_HASH_SALT provided.
        }),
      ).toThrow(/PHONE_HASH_SALT is required when NODE_ENV=production/);
    });

    it('accepts PHONE_HASH_SALT in development without a value', () => {
      // In dev/test, PHONE_HASH_SALT is optional — the container falls back to a
      // sentinel so local dev works without manual env editing.
      expect(() => parseEnv({ NODE_ENV: 'development' })).not.toThrow();
    });
  });

  describe('STORAGE_READ_URL_MAX_SECONDS', () => {
    it('is undefined when omitted', () => {
      const result = parseEnv({});
      expect(result.STORAGE_READ_URL_MAX_SECONDS).toBeUndefined();
    });

    it('coerces a string to a number', () => {
      const result = parseEnv({ STORAGE_READ_URL_MAX_SECONDS: '1800' });
      expect(result.STORAGE_READ_URL_MAX_SECONDS).toBe(1800);
    });

    it('rejects a value above the 86400 cap', () => {
      expect(() => parseEnv({ STORAGE_READ_URL_MAX_SECONDS: '86401' })).toThrow();
    });

    it('rejects zero', () => {
      expect(() => parseEnv({ STORAGE_READ_URL_MAX_SECONDS: '0' })).toThrow();
    });
  });

  describe('STORAGE_UPLOAD_URL_MAX_SECONDS', () => {
    it('is undefined when omitted', () => {
      const result = parseEnv({});
      expect(result.STORAGE_UPLOAD_URL_MAX_SECONDS).toBeUndefined();
    });

    it('coerces a string to a number', () => {
      const result = parseEnv({ STORAGE_UPLOAD_URL_MAX_SECONDS: '300' });
      expect(result.STORAGE_UPLOAD_URL_MAX_SECONDS).toBe(300);
    });

    it('rejects a value above the 3600 cap', () => {
      expect(() => parseEnv({ STORAGE_UPLOAD_URL_MAX_SECONDS: '3601' })).toThrow();
    });

    it('rejects zero', () => {
      expect(() => parseEnv({ STORAGE_UPLOAD_URL_MAX_SECONDS: '0' })).toThrow();
    });
  });

  describe('empty-string optional handling', () => {
    it('optionalString() parses "" to undefined', () => {
      const schema = optionalString();
      expect(schema.parse('')).toBeUndefined();
    });

    it('optionalString() parses undefined to undefined', () => {
      const schema = optionalString();
      expect(schema.parse(undefined)).toBeUndefined();
    });

    it('optionalString() parses a non-empty string through unchanged', () => {
      const schema = optionalString();
      expect(schema.parse('value')).toBe('value');
    });

    it('optionalString() with whitespace-only input passes through unchanged (no trimming)', () => {
      // Deliberate: the preprocessor only collapses literal "". Whitespace-only
      // strings are NOT coerced to undefined — "   " is an operator error (someone
      // set the env var to spaces), not a placeholder. We do NOT trim because that
      // would mask real input errors; the value passes min(1) since it has length > 0
      // and surfaces as a present (but space-only) string. Ops must fix the .env.
      const schema = optionalString();
      expect(schema.parse('   ')).toBe('   ');
    });

    it('optionalString(32) rejects a string shorter than 32 chars', () => {
      const schema = optionalString(32);
      expect(() => schema.parse('short')).toThrow();
    });

    it('optionalString(32) accepts a 32-character string', () => {
      const schema = optionalString(32);
      expect(schema.parse('a'.repeat(32))).toBe('a'.repeat(32));
    });

    it('envSchema with TWILIO_ACCOUNT_SID="" and SMS_TRANSPORT=log parses successfully (cascade fix)', () => {
      // Core regression test: empty-string placeholder in .env with dev/log transport
      // must NOT cause a schema failure. This was the root cause of the qa cascade.
      expect(() =>
        parseEnv({
          SMS_TRANSPORT: 'log',
          TWILIO_ACCOUNT_SID: '',
        }),
      ).not.toThrow();
    });

    it('envSchema with TWILIO_ACCOUNT_SID="" and SMS_TRANSPORT=twilio still fails superRefine', () => {
      // Empty-string becomes undefined after preprocessing, which means
      // !data.TWILIO_ACCOUNT_SID is true — the production-safety guard still fires.
      expect(() =>
        parseEnv({
          SMS_TRANSPORT: 'twilio',
          TWILIO_ACCOUNT_SID: '',
          TWILIO_AUTH_TOKEN: 'authtest',
          TWILIO_VERIFY_SERVICE_SID: 'VAtest',
        }),
      ).toThrow(/TWILIO_ACCOUNT_SID is required when SMS_TRANSPORT=twilio/);
    });

    it('envSchema with STORAGE_TRANSPORT=s3 and STORAGE_BUCKET="" rejects with the s3 guard message', () => {
      // Empty-string is coerced to undefined by optionalString(). The superRefine
      // block checks !data.STORAGE_BUCKET, so undefined correctly triggers the guard.
      expect(() =>
        parseEnv({
          STORAGE_TRANSPORT: 's3',
          STORAGE_BUCKET: '',
          STORAGE_REGION: 'ap-southeast-1',
          STORAGE_ACCESS_KEY_ID: 'AKIATEST',
          STORAGE_SECRET_ACCESS_KEY: 'secrettest',
        }),
      ).toThrow(/STORAGE_BUCKET is required when STORAGE_TRANSPORT=s3/);
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

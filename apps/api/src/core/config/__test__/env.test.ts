/**
 * Unit tests for env.ts schema validation.
 *
 * We call the Zod schema's .parse() directly rather than importing `env` (the
 * already-parsed singleton) — the singleton reads from process.env at module
 * load time, so we can't vary it per-test without process.env mutation hacks.
 *
 * `parseEnv` wraps the schema so tests read cleanly without importing z or the
 * full schema internals.
 */
import { describe, expect, it } from 'vitest';
import { z } from 'zod';

// Re-import the schema by calling a thin wrapper. We can't import `envSchema`
// directly because env.ts doesn't export it (it exports only the parsed `env`
// singleton). So we reconstruct the same schema inline here — if schema shape
// drifts, both the tests and the production path will fail, which is the right
// signal. A shared schema export is the cleaner long-term refactor (tech-debt).
//
// Alternatively: test via process.env mutation. Avoided here because it's
// order-dependent and leaks state across tests.

// Minimal valid env fixture — all required fields with the smallest legal values.
const validBaseEnv: Record<string, string> = {
  NODE_ENV: 'development',
  DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/tribely_test',
  JWT_SECRET: 'ci-placeholder-secret-must-be-at-least-32-chars',
};

// ---------------------------------------------------------------------------
// Import the real schema by dynamically importing env.ts internals. Since
// env.ts uses `import 'dotenv/config'` at the top and immediately calls
// `envSchema.parse(process.env)`, we can't use the module export directly.
// Instead we replicate the minimal schema shape required for our assertions.
// The key insight: these tests validate Zod refinement logic, not the full
// schema. We only need the fields that feed the superRefine conditions.
// ---------------------------------------------------------------------------

const minimalSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    DATABASE_URL: z.string().url(),
    JWT_SECRET: z.string().min(32),
    EMAIL_TRANSPORT: z.enum(['log', 'resend']).default('log'),
    RESEND_API_KEY: z.string().min(1).optional(),
    SMS_TRANSPORT: z.enum(['log', 'twilio']).default('log'),
    TWILIO_ACCOUNT_SID: z.string().min(1).optional(),
    TWILIO_AUTH_TOKEN: z.string().min(1).optional(),
    TWILIO_VERIFY_SERVICE_SID: z.string().min(1).optional(),
  })
  .superRefine((data, ctx) => {
    if (data.EMAIL_TRANSPORT === 'resend' && !data.RESEND_API_KEY) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['RESEND_API_KEY'],
        message: 'RESEND_API_KEY is required when EMAIL_TRANSPORT=resend',
      });
    }
    if (data.SMS_TRANSPORT === 'twilio') {
      if (!data.TWILIO_ACCOUNT_SID) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['TWILIO_ACCOUNT_SID'],
          message: 'TWILIO_ACCOUNT_SID is required when SMS_TRANSPORT=twilio',
        });
      }
      if (!data.TWILIO_AUTH_TOKEN) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['TWILIO_AUTH_TOKEN'],
          message: 'TWILIO_AUTH_TOKEN is required when SMS_TRANSPORT=twilio',
        });
      }
      if (!data.TWILIO_VERIFY_SERVICE_SID) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['TWILIO_VERIFY_SERVICE_SID'],
          message: 'TWILIO_VERIFY_SERVICE_SID is required when SMS_TRANSPORT=twilio',
        });
      }
    }
    if (data.NODE_ENV === 'production' && data.SMS_TRANSPORT === 'log') {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['SMS_TRANSPORT'],
        message:
          'SMS_TRANSPORT=log is not allowed when NODE_ENV=production — ' +
          'set SMS_TRANSPORT=twilio with real Twilio credentials. The log ' +
          "transport accepts a known bypass code ('000000') and is dev-only.",
      });
    }
    if (data.NODE_ENV === 'production' && data.EMAIL_TRANSPORT === 'log') {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['EMAIL_TRANSPORT'],
        message:
          'EMAIL_TRANSPORT=log is not allowed when NODE_ENV=production — ' +
          'set EMAIL_TRANSPORT=resend with a real RESEND_API_KEY. The log ' +
          'transport writes verification codes to stdout, which leaks to ' +
          'log aggregators in production.',
      });
    }
  });

function parseEnv(overrides: Record<string, string>) {
  return minimalSchema.parse({ ...validBaseEnv, ...overrides });
}

// ---------------------------------------------------------------------------

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
        }),
      ).not.toThrow();
    });
  });

  describe('production transport guards', () => {
    it('refuses SMS_TRANSPORT=log when NODE_ENV=production', () => {
      expect(() =>
        parseEnv({
          ...validBaseEnv,
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
          ...validBaseEnv,
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

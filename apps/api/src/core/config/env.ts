// Load `apps/api/.env` into process.env before Zod parses below.
// This must be the very first import in the module — otherwise the schema
// runs against an empty process.env and the app crashes at boot.
import 'dotenv/config';
import { z } from 'zod';

/**
 * Optional string env var that treats `""` (empty string) as `undefined`.
 *
 * Background: shell-style `.env` files commonly carry placeholder lines like
 * `TWILIO_ACCOUNT_SID=` (assignment with no value). Without preprocessing,
 * Zod sees `""` as a present value and rejects it under `.min(1)` — but the
 * field is `.optional()`, so the intent of an empty placeholder is "not set,
 * use the default / skip." Coerce to `undefined` so optional behavior matches
 * developer expectation. Required string fields (DATABASE_URL, JWT_SECRET)
 * deliberately do NOT use this helper — they must be set to a real value.
 */
export const optionalString = (min = 1) =>
  z.preprocess((v) => (v === '' ? undefined : v), z.string().min(min).optional());

export const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().int().positive().default(3000),
    LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),

    DATABASE_URL: z.string().url(),

    JWT_SECRET: z.string().min(32),
    JWT_ACCESS_TTL: z.string().default('15m'),
    JWT_REFRESH_TTL: z.string().default('30d'),
    EMAIL_VERIFICATION_TTL: z.string().default('48h'),
    PASSWORD_RESET_TTL: z.string().default('24h'),

    // Email — `log` writes to the logger (dev default), `resend` hits the
    // real Resend API. Selection is explicit (not inferred from key
    // presence) so a missing key in staging fails loudly at boot instead
    // of silently dropping mail behind a stray `logger.info` line.
    EMAIL_TRANSPORT: z.enum(['log', 'resend']).default('log'),
    RESEND_API_KEY: optionalString(),
    // Defaults to Resend's onboarding sender so local dev / integration
    // tests work without DNS verification. Production must override with a
    // verified sender (e.g. `Tribely <noreply@gotribely.com>`).
    EMAIL_FROM: z.string().min(1).default('onboarding@resend.dev'),
    APP_BASE_URL: z.string().url().default('http://localhost:3000'),

    VERIFIED_SIGNAL_SET: z
      .string()
      .default('email,phone,selfie')
      .transform((s) =>
        s
          .split(',')
          .map((p) => p.trim())
          .filter(Boolean),
      )
      .pipe(z.array(z.enum(['email', 'phone', 'selfie']))),

    // SMS / phone verification — `log` writes to the logger (dev default,
    // no real sends), `twilio` hits the real Twilio Verify API. Selection
    // is explicit (not inferred from key presence) so a missing credential
    // in staging fails loudly at boot rather than silently skipping sends.
    SMS_TRANSPORT: z.enum(['log', 'twilio']).default('log'),
    TWILIO_ACCOUNT_SID: optionalString(),
    TWILIO_AUTH_TOKEN: optionalString(),
    TWILIO_VERIFY_SERVICE_SID: optionalString(),
    // Comma-separated list of E.164 country code prefixes to allow. Requests
    // from numbers NOT matching any prefix are rejected before a Twilio call
    // is made (returns { status: 'invalid' } to the caller, logs WARN for ops).
    // Default '+65' = Singapore-only for v1 launch. Add markets by changing
    // this env var — no code change required.
    SMS_ALLOWED_COUNTRY_CODES: z
      .string()
      .default('+65')
      .transform((s) => s.split(',').map((c) => c.trim()))
      .pipe(z.array(z.string().regex(/^\+[1-9]\d{0,3}$/)).min(1)),

    // Object storage — `log` writes to the logger (dev default, no real
    // uploads), `s3` hits the real AWS S3 API. Selection is explicit (not
    // inferred from key presence) so a missing credential in staging fails
    // loudly at boot rather than silently dropping uploads.
    // S3 adapter pending TRI-5 — STORAGE_TRANSPORT=s3 will throw at boot
    // until that adapter lands.
    STORAGE_TRANSPORT: z.enum(['log', 's3']).default('log'),
    STORAGE_BUCKET: optionalString(),
    STORAGE_REGION: optionalString(),
    STORAGE_ACCESS_KEY_ID: optionalString(),
    STORAGE_SECRET_ACCESS_KEY: optionalString(),
    STORAGE_ENDPOINT: z.string().url().optional(),
    STORAGE_FORCE_PATH_STYLE: z
      .union([z.boolean(), z.enum(['true', 'false']).transform((v) => v === 'true')])
      .optional()
      .default(false),
    // Hard cap (in seconds) that the adapter enforces on caller-supplied
    // `expiresInSeconds` for read (GET) presigned URLs. The DI factory applies
    // a default of 3600 (1h) when this var is absent; setting it here lets ops
    // tighten the cap without a code change.
    STORAGE_READ_URL_MAX_SECONDS: z.coerce.number().int().positive().max(86400).optional(),
    // Hard cap for upload (PUT) presigned URLs. The DI factory applies a
    // default of 300 (5m) when this var is absent.
    STORAGE_UPLOAD_URL_MAX_SECONDS: z.coerce.number().int().positive().max(3600).optional(),

    // Salt for one-way hashing of phone numbers before they appear in
    // long-lived outbox events (e.g. userPhoneVerificationRevoked). Must be at
    // least 32 characters. Generate with: openssl rand -hex 32
    // Boot refuses an empty/missing value when NODE_ENV=production.
    PHONE_HASH_SALT: optionalString(32),

    // Safety-report destination mailbox. Required. Defaults to the ops mailbox
    // so dev "just works" without an env override.
    SAFETY_REPORT_EMAIL: z.string().email().default('safety@gotribely.com'),

    // How often the selfie-deletion audit table is swept for rows older than
    // the 24-month PDPA retention window (PDPA s25). Default 86400000 ms = 24h.
    // Reject anything below 60000 ms (1 min) to prevent Postgres churn.
    SELFIE_DELETION_SWEEP_INTERVAL_MS: z.coerce
      .number()
      .int()
      .min(60_000, 'SELFIE_DELETION_SWEEP_INTERVAL_MS must be at least 60000 ms (1 min)')
      .optional()
      .default(86_400_000),

    // TRI-79 — How often the selfie retention sweep job runs to find and
    // permanently delete selfies eligible for retention deletion (approved or
    // rejected ≥ 30 days ago). Default 86400000 ms = 24h.
    // Reject anything below 60000 ms (1 min) to prevent Postgres churn.
    SELFIE_RETENTION_SWEEP_INTERVAL_MS: z.coerce
      .number()
      .int()
      .min(60_000, 'SELFIE_RETENTION_SWEEP_INTERVAL_MS must be at least 60000 ms (1 min)')
      .optional()
      .default(86_400_000),
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

    // Production transport safety guards. Both log adapters are dev-only:
    // - SMS_TRANSPORT=log accepts the magic bypass code '000000' for any phone.
    // - EMAIL_TRANSPORT=log writes OTP codes to stdout, which leaks them to
    //   log aggregators in any environment with centralised logging.
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

    if (data.STORAGE_TRANSPORT === 's3') {
      if (!data.STORAGE_BUCKET) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['STORAGE_BUCKET'],
          message: 'STORAGE_BUCKET is required when STORAGE_TRANSPORT=s3',
        });
      }
      if (!data.STORAGE_REGION) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['STORAGE_REGION'],
          message: 'STORAGE_REGION is required when STORAGE_TRANSPORT=s3',
        });
      }
      if (!data.STORAGE_ACCESS_KEY_ID) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['STORAGE_ACCESS_KEY_ID'],
          message: 'STORAGE_ACCESS_KEY_ID is required when STORAGE_TRANSPORT=s3',
        });
      }
      if (!data.STORAGE_SECRET_ACCESS_KEY) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['STORAGE_SECRET_ACCESS_KEY'],
          message: 'STORAGE_SECRET_ACCESS_KEY is required when STORAGE_TRANSPORT=s3',
        });
      }
    }
    if (data.NODE_ENV === 'production' && data.STORAGE_TRANSPORT === 'log') {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['STORAGE_TRANSPORT'],
        message:
          'STORAGE_TRANSPORT=log is not allowed when NODE_ENV=production — ' +
          'set STORAGE_TRANSPORT=s3 with real AWS credentials.',
      });
    }

    if (data.NODE_ENV === 'production' && !data.PHONE_HASH_SALT) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['PHONE_HASH_SALT'],
        message:
          'PHONE_HASH_SALT is required when NODE_ENV=production — ' +
          'set it to a random string of at least 32 characters. ' +
          'Generate with: openssl rand -hex 32',
      });
    }
  });

export type Env = z.infer<typeof envSchema>;

export const env: Env = envSchema.parse(process.env);

// Load `apps/api/.env` into process.env before Zod parses below.
// This must be the very first import in the module — otherwise the schema
// runs against an empty process.env and the app crashes at boot.
import 'dotenv/config';
import { z } from 'zod';

const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().int().positive().default(3000),
    LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),

    DATABASE_URL: z.string().url(),

    JWT_SECRET: z.string().min(32),
    JWT_ACCESS_TTL: z.string().default('15m'),
    JWT_REFRESH_TTL: z.string().default('30d'),
    EMAIL_VERIFICATION_TTL: z.string().default('48h'),

    // Email — `log` writes to the logger (dev default), `resend` hits the
    // real Resend API. Selection is explicit (not inferred from key
    // presence) so a missing key in staging fails loudly at boot instead
    // of silently dropping mail behind a stray `logger.info` line.
    EMAIL_TRANSPORT: z.enum(['log', 'resend']).default('log'),
    RESEND_API_KEY: z.string().min(1).optional(),
    // Defaults to Resend's onboarding sender so local dev / integration
    // tests work without DNS verification. Production must override with a
    // verified sender (e.g. `Tribely <noreply@gotribely.com>`).
    EMAIL_FROM: z.string().min(1).default('onboarding@resend.dev'),
    APP_BASE_URL: z.string().url().default('http://localhost:3000'),
  })
  .superRefine((data, ctx) => {
    if (data.EMAIL_TRANSPORT === 'resend' && !data.RESEND_API_KEY) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['RESEND_API_KEY'],
        message: 'RESEND_API_KEY is required when EMAIL_TRANSPORT=resend',
      });
    }
  });

export type Env = z.infer<typeof envSchema>;

export const env: Env = envSchema.parse(process.env);

import { logger } from '../middleware/logger.js';
import type { EmailSender } from './email-sender.port.js';

/**
 * Dev/test adapter — logs the email instead of sending it. Used when
 * `EMAIL_TRANSPORT=log` (default in development), so engineers can see the
 * verification / reset codes in their console without burning Resend quota or
 * needing real DNS-verified sender domains.
 *
 * Production must set `EMAIL_TRANSPORT=resend` (env validation enforces
 * this combined with a real `RESEND_API_KEY`).
 */
export class LoggingEmailSender implements EmailSender {
  // No `async` — these are synchronous logger calls. Wrapping with
  // Promise.resolve honors the port contract without `require-await`.
  sendVerification(input: { to: string; code: string }): Promise<void> {
    logger.info(
      { to: input.to, code: input.code },
      'email.sendVerification (DEV — not actually sent)',
    );
    return Promise.resolve();
  }

  sendPasswordReset(input: { to: string; code: string }): Promise<void> {
    logger.info(
      { to: input.to, code: input.code },
      'email.sendPasswordReset (DEV — not actually sent)',
    );
    return Promise.resolve();
  }
}

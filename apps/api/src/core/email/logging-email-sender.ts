import { logger } from '../middleware/logger.js';
import type { EmailSender } from './email-sender.port.js';

/**
 * Dev/test adapter — logs the email instead of sending it. Used when
 * `EMAIL_TRANSPORT=log` (default in development), so engineers can see email
 * content (subject, recipient) in their console without burning Resend quota
 * or needing real DNS-verified sender domains.
 *
 * Production must set `EMAIL_TRANSPORT=resend` (env validation enforces
 * this combined with a real `RESEND_API_KEY`).
 */
export class LoggingEmailSender implements EmailSender {
  // No `async` — this is a synchronous logger call. Wrapping with
  // Promise.resolve honors the port contract without `require-await`.
  send(input: { to: string; subject: string; html: string; text: string }): Promise<void> {
    logger.info({ to: input.to, subject: input.subject }, 'email.send (DEV — not actually sent)');
    return Promise.resolve();
  }
}

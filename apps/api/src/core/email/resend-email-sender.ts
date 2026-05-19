import { Resend } from 'resend';
import type { EmailSender } from './email-sender.port.js';

/**
 * Production adapter backed by Resend (https://resend.com). The Resend SDK
 * surfaces failures as `result.error` rather than throwing — wrap and throw
 * here so callers get the same exception-based error contract as every
 * other adapter in this codebase.
 *
 * The `from` address must be a Resend-verified sender domain in production.
 * For first-time setup or smoke tests, `onboarding@resend.dev` works but
 * delivers only to the Resend account's verified email.
 *
 * This adapter is a primitive transport: it does not compose templates.
 * Callers (feature use cases) are responsible for building subject/html/text
 * via template functions in `core/email/templates/`.
 */
export class ResendEmailSender implements EmailSender {
  private readonly client: Resend;

  constructor(
    apiKey: string,
    private readonly from: string,
  ) {
    this.client = new Resend(apiKey);
  }

  async send(input: { to: string; subject: string; html: string; text: string }): Promise<void> {
    const result = await this.client.emails.send({
      from: this.from,
      to: input.to,
      subject: input.subject,
      html: input.html,
      text: input.text,
    });
    if (result.error) {
      throw new Error(`Resend send failed: ${result.error.name}: ${result.error.message}`);
    }
  }
}

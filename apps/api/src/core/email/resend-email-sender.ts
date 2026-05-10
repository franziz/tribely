import { Resend } from 'resend';
import type { EmailSender } from './email-sender.port.js';
import { passwordResetTemplate } from './templates/password-reset.template.js';
import { verificationTemplate } from './templates/verification.template.js';

/**
 * Production adapter backed by Resend (https://resend.com). The Resend SDK
 * surfaces failures as `result.error` rather than throwing — wrap and throw
 * here so callers get the same exception-based error contract as every
 * other adapter in this codebase.
 *
 * The `from` address must be a Resend-verified sender domain in production.
 * For first-time setup or smoke tests, `onboarding@resend.dev` works but
 * delivers only to the Resend account's verified email.
 */
export class ResendEmailSender implements EmailSender {
  private readonly client: Resend;

  constructor(
    apiKey: string,
    private readonly from: string,
  ) {
    this.client = new Resend(apiKey);
  }

  async sendVerification(input: { to: string; verifyUrl: string }): Promise<void> {
    const { subject, html, text } = verificationTemplate({ verifyUrl: input.verifyUrl });
    await this.send(input.to, subject, html, text);
  }

  async sendPasswordReset(input: { to: string; resetUrl: string }): Promise<void> {
    const { subject, html, text } = passwordResetTemplate({ resetUrl: input.resetUrl });
    await this.send(input.to, subject, html, text);
  }

  private async send(to: string, subject: string, html: string, text: string): Promise<void> {
    const result = await this.client.emails.send({ from: this.from, to, subject, html, text });
    if (result.error) {
      throw new Error(`Resend send failed: ${result.error.name}: ${result.error.message}`);
    }
  }
}

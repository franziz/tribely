import type { EmailSender } from './email-sender.port.js';

export interface RecordedEmail {
  to: string;
  subject: string;
  html: string;
  text: string;
}

/**
 * In-memory test double. Records every `send` call for later assertion.
 * Use in place of `ResendEmailSender` when unit-testing use cases that emit
 * email (e.g. TRI-14 password reset, TRI-15 email verification, TRI-29
 * safety reports).
 *
 * Tests that previously asserted on `kind` ('verification' | 'password-reset')
 * should instead match on `subject` or inspect `html`/`text` content, since
 * template composition is now the use case's responsibility.
 */
export class FakeEmailSender implements EmailSender {
  readonly sent: RecordedEmail[] = [];

  send(input: { to: string; subject: string; html: string; text: string }): Promise<void> {
    this.sent.push({ to: input.to, subject: input.subject, html: input.html, text: input.text });
    return Promise.resolve();
  }
}

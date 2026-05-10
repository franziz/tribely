import type { EmailSender } from '../email-sender.port.js';

export interface RecordedVerification {
  kind: 'verification';
  to: string;
  verifyUrl: string;
}

export interface RecordedPasswordReset {
  kind: 'password-reset';
  to: string;
  resetUrl: string;
}

export type RecordedEmail = RecordedVerification | RecordedPasswordReset;

/**
 * In-memory test double. Records every send for later assertion. Use in
 * place of `ResendEmailSender` when unit-testing use cases that emit email
 * (e.g. TRI-14 password reset, TRI-15 email verification).
 */
export class FakeEmailSender implements EmailSender {
  readonly sent: RecordedEmail[] = [];

  sendVerification(input: { to: string; verifyUrl: string }): Promise<void> {
    this.sent.push({ kind: 'verification', to: input.to, verifyUrl: input.verifyUrl });
    return Promise.resolve();
  }

  sendPasswordReset(input: { to: string; resetUrl: string }): Promise<void> {
    this.sent.push({ kind: 'password-reset', to: input.to, resetUrl: input.resetUrl });
    return Promise.resolve();
  }
}

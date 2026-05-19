import type { EmailSender } from './email-sender.port.js';

export interface RecordedVerification {
  kind: 'verification';
  to: string;
  code: string;
}

export interface RecordedPasswordReset {
  kind: 'password-reset';
  to: string;
  code: string;
}

export type RecordedEmail = RecordedVerification | RecordedPasswordReset;

/**
 * In-memory test double. Records every send for later assertion. Use in
 * place of `ResendEmailSender` when unit-testing use cases that emit email
 * (e.g. TRI-14 password reset, TRI-15 email verification).
 */
export class FakeEmailSender implements EmailSender {
  readonly sent: RecordedEmail[] = [];

  sendVerification(input: { to: string; code: string }): Promise<void> {
    this.sent.push({ kind: 'verification', to: input.to, code: input.code });
    return Promise.resolve();
  }

  sendPasswordReset(input: { to: string; code: string }): Promise<void> {
    this.sent.push({ kind: 'password-reset', to: input.to, code: input.code });
    return Promise.resolve();
  }
}

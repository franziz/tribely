// Load apps/api/.env so RESEND_API_KEY / EMAIL_TEST_RECIPIENT can be set
// in the dotenv file rather than inlined on the command line. Must run
// before the const reads below — ESM imports execute first, side effect
// included.
import 'dotenv/config';
import { describe, expect, it } from 'vitest';
import { ResendEmailSender } from './resend-email-sender.js';

const apiKey = process.env.RESEND_API_KEY;
const from = process.env.EMAIL_FROM ?? 'onboarding@resend.dev';
const realRecipient = process.env.EMAIL_TEST_RECIPIENT;

/**
 * Real-API integration test. Skips when `RESEND_API_KEY` is unset so PRs
 * without the secret still pass. Uses Resend's built-in test recipients
 * (`delivered@resend.dev`) which simulate delivery outcomes without
 * actually emailing anyone.
 *
 * Replaces the manual "trigger send, confirm receipt" step from TRI-3's
 * acceptance criteria with an automated equivalent.
 *
 * Construction is lazy (inside each `it`) because `describe.skipIf` still
 * evaluates the describe body at registration time — and the Resend SDK
 * constructor throws synchronously on a missing key.
 *
 * Setting `EMAIL_TEST_RECIPIENT=you@example.com` opts into a third + fourth
 * test that delivers to your real inbox — useful for eyeballing the
 * rendered template. With `EMAIL_FROM=onboarding@resend.dev`, Resend will
 * only deliver to the email registered with your Resend account.
 */
describe('ResendEmailSender (integration)', () => {
  it.skipIf(!apiKey)(
    'sends a verification email to delivered@resend.dev',
    async () => {
      const sender = new ResendEmailSender(apiKey ?? '', from);
      await expect(
        sender.sendVerification({
          to: 'delivered@resend.dev',
          verifyUrl: 'https://example.tribely.app/auth/verify?token=integration-test',
        }),
      ).resolves.toBeUndefined();
    },
    15_000,
  );

  it.skipIf(!apiKey)(
    'sends a password-reset email to delivered@resend.dev',
    async () => {
      const sender = new ResendEmailSender(apiKey ?? '', from);
      await expect(
        sender.sendPasswordReset({
          to: 'delivered@resend.dev',
          resetUrl: 'https://example.tribely.app/auth/reset?token=integration-test',
        }),
      ).resolves.toBeUndefined();
    },
    15_000,
  );

  it.skipIf(!apiKey || !realRecipient)(
    'delivers a verification email to EMAIL_TEST_RECIPIENT (eyeball test)',
    async () => {
      const sender = new ResendEmailSender(apiKey ?? '', from);
      await expect(
        sender.sendVerification({
          to: realRecipient ?? '',
          verifyUrl: 'https://example.tribely.app/auth/verify?token=eyeball-test',
        }),
      ).resolves.toBeUndefined();
    },
    15_000,
  );

  it.skipIf(!apiKey || !realRecipient)(
    'delivers a password-reset email to EMAIL_TEST_RECIPIENT (eyeball test)',
    async () => {
      const sender = new ResendEmailSender(apiKey ?? '', from);
      await expect(
        sender.sendPasswordReset({
          to: realRecipient ?? '',
          resetUrl: 'https://example.tribely.app/auth/reset?token=eyeball-test',
        }),
      ).resolves.toBeUndefined();
    },
    15_000,
  );
});

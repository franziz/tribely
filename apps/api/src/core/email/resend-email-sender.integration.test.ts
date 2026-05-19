// Load apps/api/.env so RESEND_API_KEY / EMAIL_TEST_RECIPIENT can be set
// in the dotenv file rather than inlined on the command line. Must run
// before the const reads below — ESM imports execute first, side effect
// included.
import 'dotenv/config';
import { describe, expect, it } from 'vitest';
import { passwordResetTemplate } from './templates/password-reset.template.js';
import { verificationTemplate } from './templates/verification.template.js';
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
 * Template composition is the caller's responsibility — these tests use the
 * canonical template functions from `core/email/templates/` to exercise the
 * full real-world path: template → send.
 *
 * Setting `EMAIL_TEST_RECIPIENT=you@example.com` opts into a third + fourth
 * test that delivers to your real inbox — useful for eyeballing the rendered
 * template. With `EMAIL_FROM=onboarding@resend.dev`, Resend will only deliver
 * to the email registered with your Resend account.
 */
describe('ResendEmailSender (integration)', () => {
  it.skipIf(!apiKey)(
    'sends a verification email to delivered@resend.dev',
    async () => {
      const sender = new ResendEmailSender(apiKey ?? '', from);
      const { subject, html, text } = verificationTemplate({ code: '482917' });
      await expect(
        sender.send({ to: 'delivered@resend.dev', subject, html, text }),
      ).resolves.toBeUndefined();
    },
    15_000,
  );

  it.skipIf(!apiKey)(
    'sends a password-reset email to delivered@resend.dev',
    async () => {
      const sender = new ResendEmailSender(apiKey ?? '', from);
      const { subject, html, text } = passwordResetTemplate({ code: '739104' });
      await expect(
        sender.send({ to: 'delivered@resend.dev', subject, html, text }),
      ).resolves.toBeUndefined();
    },
    15_000,
  );

  it.skipIf(!apiKey || !realRecipient)(
    'delivers a verification email to EMAIL_TEST_RECIPIENT (eyeball test)',
    async () => {
      const sender = new ResendEmailSender(apiKey ?? '', from);
      const { subject, html, text } = verificationTemplate({ code: '482917' });
      await expect(
        sender.send({ to: realRecipient ?? '', subject, html, text }),
      ).resolves.toBeUndefined();
    },
    15_000,
  );

  it.skipIf(!apiKey || !realRecipient)(
    'delivers a password-reset email to EMAIL_TEST_RECIPIENT (eyeball test)',
    async () => {
      const sender = new ResendEmailSender(apiKey ?? '', from);
      const { subject, html, text } = passwordResetTemplate({ code: '739104' });
      await expect(
        sender.send({ to: realRecipient ?? '', subject, html, text }),
      ).resolves.toBeUndefined();
    },
    15_000,
  );
});

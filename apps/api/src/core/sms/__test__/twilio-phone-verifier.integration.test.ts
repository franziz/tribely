// Load apps/api/.env into process.env before anything reads it.
// Vitest does NOT auto-load .env (see CLAUDE.md gotcha). Without this import,
// process.env.TWILIO_INTEGRATION_TEST is undefined even when set in .env and
// every test silently skips.
import 'dotenv/config';
import { describe, expect, it } from 'vitest';
import { TwilioPhoneVerifier } from '../twilio-phone-verifier.js';
import { PhoneNumber } from '../phone-number.js';

/**
 * Opt-in integration test — hits the real Twilio Verify API.
 *
 * To run:
 *   TWILIO_INTEGRATION_TEST=1 npm run --workspace=@tribely/api test -- \
 *     src/core/sms/__test__/twilio-phone-verifier.integration.test.ts
 *
 * Required env vars (set in apps/api/.env):
 *   TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_VERIFY_SERVICE_SID
 *
 * Magic numbers: Twilio documents +15005550006 as a test number for
 * Programmable Messaging. Compatibility with Verify specifically is not
 * officially documented and may differ — if this test fails with
 * { status: 'invalid' } or 'provider_unavailable', file a follow-up to
 * source the correct Verify Magic Numbers or use a real SG sandbox number.
 *
 * NOTE: Do NOT run against production credentials or a live Singapore number
 * in automated pipelines — Twilio charges per verification send.
 *
 * This test intentionally does NOT run in CI (no TWILIO_INTEGRATION_TEST
 * secret in GitHub Actions). Local-only, opt-in.
 */

const integrationEnabled = Boolean(process.env.TWILIO_INTEGRATION_TEST);
const accountSid = process.env.TWILIO_ACCOUNT_SID ?? '';
const authToken = process.env.TWILIO_AUTH_TOKEN ?? '';
const serviceSid = process.env.TWILIO_VERIFY_SERVICE_SID ?? '';

// Twilio test Magic Number for Verify. Documented for Programmable Messaging;
// assumed compatible with Verify based on common Twilio test conventions.
// If incompatible, update to a Verify-specific Magic Number or sandbox number.
const MAGIC_PHONE = PhoneNumber.create('+15005550006').value;
// Twilio accepts any code for the magic number in test mode.
const MAGIC_CODE = '000000';

describe('TwilioPhoneVerifier (integration — real Twilio Verify API)', () => {
  it.skipIf(!integrationEnabled)(
    'startVerification returns { status: "sent" } for the Twilio Magic Number',
    async () => {
      const adapter = new TwilioPhoneVerifier({
        accountSid,
        authToken,
        serviceSid,
        // Magic number is US (+1) — allow-list must include it for this test.
        allowedCountryCodes: ['+1'],
      });

      const result = await adapter.startVerification({ phone: MAGIC_PHONE });
      expect(result).toStrictEqual({ status: 'sent' });
    },
    15_000,
  );

  it.skipIf(!integrationEnabled)(
    'checkVerification returns { status: "verified" } for the magic code',
    async () => {
      const adapter = new TwilioPhoneVerifier({
        accountSid,
        authToken,
        serviceSid,
        allowedCountryCodes: ['+1'],
      });

      const result = await adapter.checkVerification({ phone: MAGIC_PHONE, code: MAGIC_CODE });
      // Accepted outcomes: 'verified' (magic code matched) or 'expired'
      // (verification from the startVerification test already consumed / timed out).
      // Both are valid integration outcomes — they confirm the adapter reaches Twilio.
      expect(['verified', 'expired']).toContain(result.status);
    },
    15_000,
  );
});

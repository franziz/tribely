import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { PhoneVerifier } from './phone-verifier.port.js';
import { PhoneNumber } from './phone-number.js';
import { runPhoneVerifierContract } from './phone-verifier.contract.js';

// --- Mock the twilio module BEFORE importing the adapter ---
// vi.mock() is hoisted above all imports by Vitest, so closures inside the
// factory must reference variables declared via vi.hoisted() — those are
// evaluated before the factory runs.
//
// We use a synchronous plain-object factory (no importOriginal spread) because
// the adapter's error detection uses a duck-type guard (isTwilioRestException),
// not `instanceof RestException`. Plain objects seeded with { status, code }
// satisfy the guard exactly as real SDK errors would.
const { verificationsCreate, verificationChecksCreate } = vi.hoisted(() => ({
  verificationsCreate: vi.fn(),
  verificationChecksCreate: vi.fn(),
}));

vi.mock('twilio', () => ({
  default: vi.fn().mockReturnValue({
    verify: {
      v2: {
        services: vi.fn().mockReturnValue({
          verifications: { create: verificationsCreate },
          verificationChecks: { create: verificationChecksCreate },
        }),
      },
    },
  }),
}));

// Import adapter AFTER vi.mock so it picks up the mocked SDK.
const { TwilioPhoneVerifier } = await import('./twilio-phone-verifier.js');

// --- Helpers ---

const SG_PHONE = PhoneNumber.create('+6591234567').value;
const US_PHONE = PhoneNumber.create('+12125550100').value; // not in SG allow-list

const DEFAULT_CONFIG = {
  accountSid: 'ACtest',
  authToken: 'authtest',
  serviceSid: 'VAtest',
  allowedCountryCodes: ['+65'],
};

function makeAdapter(overrides: Partial<typeof DEFAULT_CONFIG> = {}): PhoneVerifier {
  return new TwilioPhoneVerifier({ ...DEFAULT_CONFIG, ...overrides });
}

/**
 * Build a plain Twilio-wire-shaped error object. The adapter uses a duck-type
 * guard (`isTwilioRestException`) rather than `instanceof RestException`, so a
 * plain object with `{ status, code, message }` is sufficient and avoids the
 * module-identity problem that breaks `instanceof` across vitest mock boundaries.
 */
const twilioError = (status: number, code?: number, message = 'Error') => ({
  status,
  code,
  message,
});

// --- Contract suite (runs against a mocked-SDK adapter seeded to happy-path defaults) ---

beforeEach(() => {
  vi.clearAllMocks();
  // Default happy-path seeds so the contract suite resolves cleanly.
  verificationsCreate.mockResolvedValue({ status: 'pending' });
  verificationChecksCreate.mockResolvedValue({ status: 'approved' });
});

runPhoneVerifierContract('TwilioPhoneVerifier (mocked SDK)', () => makeAdapter());

// --- startVerification mapping table (§3 of brief) ---

describe('TwilioPhoneVerifier.startVerification', () => {
  describe('allow-list gate', () => {
    it('returns { status: "invalid" } for a phone with a country code not in the allow-list', async () => {
      const adapter = makeAdapter();
      const result = await adapter.startVerification({ phone: US_PHONE });
      expect(result).toStrictEqual({ status: 'invalid' });
      expect(verificationsCreate).not.toHaveBeenCalled();
    });

    it('passes through to Twilio for a phone in the allow-list', async () => {
      const adapter = makeAdapter();
      await adapter.startVerification({ phone: SG_PHONE });
      expect(verificationsCreate).toHaveBeenCalledWith({ to: SG_PHONE, channel: 'sms' });
    });

    it('checks longest prefix first — "+659" takes priority over "+65" for +6591234567', async () => {
      const adapter = makeAdapter({ allowedCountryCodes: ['+659', '+65'] });
      const result = await adapter.startVerification({ phone: SG_PHONE });
      expect(result).toStrictEqual({ status: 'sent' });
    });
  });

  describe('success', () => {
    it('returns { status: "sent" } when Twilio returns status "pending"', async () => {
      verificationsCreate.mockResolvedValueOnce({ status: 'pending' });
      const result = await makeAdapter().startVerification({ phone: SG_PHONE });
      expect(result).toStrictEqual({ status: 'sent' });
    });
  });

  describe('Twilio error mapping', () => {
    it('returns { status: "invalid" } for code 60200 (invalid parameter)', async () => {
      verificationsCreate.mockRejectedValueOnce(twilioError(400, 60200));
      const result = await makeAdapter().startVerification({ phone: SG_PHONE });
      expect(result).toStrictEqual({ status: 'invalid' });
    });

    it('returns { status: "rate_limited" } for code 60203 (max send attempts)', async () => {
      verificationsCreate.mockRejectedValueOnce(twilioError(429, 60203));
      const result = await makeAdapter().startVerification({ phone: SG_PHONE });
      expect(result).toStrictEqual({ status: 'rate_limited' });
    });

    it('returns { status: "rate_limited" } for code 20429 (generic too-many-requests)', async () => {
      verificationsCreate.mockRejectedValueOnce(twilioError(429, 20429));
      const result = await makeAdapter().startVerification({ phone: SG_PHONE });
      expect(result).toStrictEqual({ status: 'rate_limited' });
    });

    it('returns { status: "provider_unavailable" } for HTTP 500', async () => {
      verificationsCreate.mockRejectedValueOnce(twilioError(500));
      const result = await makeAdapter().startVerification({ phone: SG_PHONE });
      expect(result).toStrictEqual({ status: 'provider_unavailable' });
    });

    it('returns { status: "provider_unavailable" } for HTTP 503', async () => {
      verificationsCreate.mockRejectedValueOnce(twilioError(503));
      const result = await makeAdapter().startVerification({ phone: SG_PHONE });
      expect(result).toStrictEqual({ status: 'provider_unavailable' });
    });

    it('returns { status: "provider_unavailable" } for unknown Twilio code (fall-through)', async () => {
      verificationsCreate.mockRejectedValueOnce(twilioError(400, 99999));
      const result = await makeAdapter().startVerification({ phone: SG_PHONE });
      expect(result).toStrictEqual({ status: 'provider_unavailable' });
    });
  });

  describe('non-Twilio errors', () => {
    it('returns { status: "provider_unavailable" } for a network error (plain Error)', async () => {
      verificationsCreate.mockRejectedValueOnce(new Error('ECONNREFUSED'));
      const result = await makeAdapter().startVerification({ phone: SG_PHONE });
      expect(result).toStrictEqual({ status: 'provider_unavailable' });
    });

    it('returns { status: "provider_unavailable" } for a timeout (non-Error throw)', async () => {
      verificationsCreate.mockRejectedValueOnce('timeout');
      const result = await makeAdapter().startVerification({ phone: SG_PHONE });
      expect(result).toStrictEqual({ status: 'provider_unavailable' });
    });
  });
});

// --- checkVerification mapping table (§3 of brief) ---

describe('TwilioPhoneVerifier.checkVerification', () => {
  describe('allow-list gate', () => {
    it('returns { status: "invalid" } for a phone with a country code not in the allow-list', async () => {
      const adapter = makeAdapter();
      const result = await adapter.checkVerification({ phone: US_PHONE, code: '123456' });
      expect(result).toStrictEqual({ status: 'invalid' });
      expect(verificationChecksCreate).not.toHaveBeenCalled();
    });
  });

  describe('success', () => {
    it('returns { status: "verified" } when Twilio returns status "approved"', async () => {
      verificationChecksCreate.mockResolvedValueOnce({ status: 'approved' });
      const result = await makeAdapter().checkVerification({ phone: SG_PHONE, code: '123456' });
      expect(result).toStrictEqual({ status: 'verified' });
    });

    it('returns { status: "invalid" } when Twilio returns status "pending" (code wrong)', async () => {
      verificationChecksCreate.mockResolvedValueOnce({ status: 'pending' });
      const result = await makeAdapter().checkVerification({ phone: SG_PHONE, code: '000000' });
      expect(result).toStrictEqual({ status: 'invalid' });
    });
  });

  describe('Twilio error mapping', () => {
    it('returns { status: "expired" } for HTTP 404 (verification SID gone)', async () => {
      verificationChecksCreate.mockRejectedValueOnce(twilioError(404));
      const result = await makeAdapter().checkVerification({ phone: SG_PHONE, code: '123456' });
      expect(result).toStrictEqual({ status: 'expired' });
    });

    it('returns { status: "invalid" } for code 60200 (invalid parameter)', async () => {
      verificationChecksCreate.mockRejectedValueOnce(twilioError(400, 60200));
      const result = await makeAdapter().checkVerification({ phone: SG_PHONE, code: '123456' });
      expect(result).toStrictEqual({ status: 'invalid' });
    });

    it('returns { status: "rate_limited" } for code 60202 (max check attempts)', async () => {
      verificationChecksCreate.mockRejectedValueOnce(twilioError(429, 60202));
      const result = await makeAdapter().checkVerification({ phone: SG_PHONE, code: '123456' });
      expect(result).toStrictEqual({ status: 'rate_limited' });
    });

    it('returns { status: "rate_limited" } for code 20429 (generic too-many-requests)', async () => {
      verificationChecksCreate.mockRejectedValueOnce(twilioError(429, 20429));
      const result = await makeAdapter().checkVerification({ phone: SG_PHONE, code: '123456' });
      expect(result).toStrictEqual({ status: 'rate_limited' });
    });

    it('returns { status: "provider_unavailable" } for HTTP 500', async () => {
      verificationChecksCreate.mockRejectedValueOnce(twilioError(500));
      const result = await makeAdapter().checkVerification({ phone: SG_PHONE, code: '123456' });
      expect(result).toStrictEqual({ status: 'provider_unavailable' });
    });

    it('returns { status: "provider_unavailable" } for HTTP 503', async () => {
      verificationChecksCreate.mockRejectedValueOnce(twilioError(503));
      const result = await makeAdapter().checkVerification({ phone: SG_PHONE, code: '123456' });
      expect(result).toStrictEqual({ status: 'provider_unavailable' });
    });

    it('returns { status: "provider_unavailable" } for unknown Twilio code (fall-through)', async () => {
      verificationChecksCreate.mockRejectedValueOnce(twilioError(400, 99999));
      const result = await makeAdapter().checkVerification({ phone: SG_PHONE, code: '123456' });
      expect(result).toStrictEqual({ status: 'provider_unavailable' });
    });
  });

  describe('non-Twilio errors', () => {
    it('returns { status: "provider_unavailable" } for a network error (plain Error)', async () => {
      verificationChecksCreate.mockRejectedValueOnce(new Error('ECONNREFUSED'));
      const result = await makeAdapter().checkVerification({ phone: SG_PHONE, code: '123456' });
      expect(result).toStrictEqual({ status: 'provider_unavailable' });
    });

    it('returns { status: "provider_unavailable" } for a timeout (non-Error throw)', async () => {
      verificationChecksCreate.mockRejectedValueOnce('timeout');
      const result = await makeAdapter().checkVerification({ phone: SG_PHONE, code: '123456' });
      expect(result).toStrictEqual({ status: 'provider_unavailable' });
    });
  });
});

/**
 * Shared behavioral contract for every PhoneVerifier adapter.
 *
 * Usage:
 *   import { runPhoneVerifierContract } from './phone-verifier.contract.js';
 *   runPhoneVerifierContract('MyAdapter', () => new MyAdapter(...));
 *
 * Every implementation must satisfy these invariants regardless of transport:
 * 1. startVerification returns a typed result (never throws) for any valid E164.
 * 2. checkVerification returns a typed result (never throws) for any valid E164.
 * 3. Results are one of the documented discriminant literals.
 * 4. Port methods never return undefined / null.
 *
 * Adapters may return different status values for the same input (LoggingPhoneVerifier
 * always returns 'sent'; TwilioPhoneVerifier may return 'invalid' for the SG magic
 * test number when the allow-list rejects a non-'+65' prefix). What the contract
 * enforces is the shape, not the specific status — that's the adapter's own unit tests.
 */
import { describe, expect, it } from 'vitest';
import type { PhoneVerifier } from './phone-verifier.port.js';
import { PhoneNumber } from './phone-number.js';

const VALID_SG_PHONE = PhoneNumber.create('+6591234567').value;

const START_STATUSES = new Set(['sent', 'invalid', 'rate_limited', 'provider_unavailable']);
const CHECK_STATUSES = new Set([
  'verified',
  'invalid',
  'expired',
  'rate_limited',
  'provider_unavailable',
]);

export function runPhoneVerifierContract(
  suiteName: string,
  makeAdapter: () => PhoneVerifier,
): void {
  describe(`PhoneVerifier contract — ${suiteName}`, () => {
    it('startVerification resolves (never throws) for a valid E.164 number', async () => {
      const adapter = makeAdapter();
      await expect(adapter.startVerification({ phone: VALID_SG_PHONE })).resolves.toBeDefined();
    });

    it('startVerification result has a valid status discriminant', async () => {
      const adapter = makeAdapter();
      const result = await adapter.startVerification({ phone: VALID_SG_PHONE });
      expect(START_STATUSES).toContain(result.status);
    });

    it('checkVerification resolves (never throws) for a valid E.164 number + any code', async () => {
      const adapter = makeAdapter();
      await expect(
        adapter.checkVerification({ phone: VALID_SG_PHONE, code: '123456' }),
      ).resolves.toBeDefined();
    });

    it('checkVerification result has a valid status discriminant', async () => {
      const adapter = makeAdapter();
      const result = await adapter.checkVerification({ phone: VALID_SG_PHONE, code: '123456' });
      expect(CHECK_STATUSES).toContain(result.status);
    });
  });
}

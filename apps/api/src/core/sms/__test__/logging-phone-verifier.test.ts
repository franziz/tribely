import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { logger } from '../../middleware/logger.js';
import { LoggingPhoneVerifier } from '../logging-phone-verifier.js';
import { PhoneNumber } from '../phone-number.js';
import { runPhoneVerifierContract } from './phone-verifier.contract.js';

// Run the shared behavioral contract first.
runPhoneVerifierContract('LoggingPhoneVerifier', () => new LoggingPhoneVerifier());

describe('LoggingPhoneVerifier', () => {
  let infoSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    infoSpy = vi.spyOn(logger, 'info').mockImplementation(() => undefined);
  });

  afterEach(() => {
    infoSpy.mockRestore();
  });

  const phone = PhoneNumber.create('+6591234567').value;

  describe('startVerification', () => {
    it('always returns { status: "sent" }', async () => {
      const adapter = new LoggingPhoneVerifier();
      const result = await adapter.startVerification({ phone });
      expect(result).toStrictEqual({ status: 'sent' });
    });

    it('logs the event with the phone number', async () => {
      const adapter = new LoggingPhoneVerifier();
      await adapter.startVerification({ phone });
      expect(infoSpy).toHaveBeenCalledTimes(1);
      expect(infoSpy).toHaveBeenCalledWith(
        expect.objectContaining({ event: 'sms.startVerification', phone }),
        expect.stringContaining('sms.startVerification'),
      );
    });
  });

  describe('checkVerification', () => {
    it('returns { status: "verified" } when code is 000000 (magic code)', async () => {
      const adapter = new LoggingPhoneVerifier();
      const result = await adapter.checkVerification({ phone, code: '000000' });
      expect(result).toStrictEqual({ status: 'verified' });
    });

    it('returns { status: "invalid" } for any other code', async () => {
      const adapter = new LoggingPhoneVerifier();
      const result = await adapter.checkVerification({ phone, code: '123456' });
      expect(result).toStrictEqual({ status: 'invalid' });
    });

    it('logs the event with outcome', async () => {
      const adapter = new LoggingPhoneVerifier();
      await adapter.checkVerification({ phone, code: '000000' });
      expect(infoSpy).toHaveBeenCalledTimes(1);
      expect(infoSpy).toHaveBeenCalledWith(
        expect.objectContaining({ event: 'sms.checkVerification', phone, outcome: 'verified' }),
        expect.stringContaining('sms.checkVerification'),
      );
    });
  });
});

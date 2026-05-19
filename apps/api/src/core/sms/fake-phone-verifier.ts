/**
 * In-memory programmable fake for use-case tests that depend on PhoneVerifier
 * (e.g. TRI-16 sign-up flow, TRI-23 verification UI).
 *
 * NOT exported from a barrel file — consumers import this file directly:
 *   import { FakePhoneVerifier } from '@/core/sms/fake-phone-verifier.js';
 *
 * This avoids accidentally pulling test infrastructure into production bundles.
 *
 * Usage:
 *   const fake = new FakePhoneVerifier();
 *   fake.setNextStartResult({ status: 'sent' });
 *   await useCase.execute({ phone: '+6591234567' });
 *   expect(fake.lastStartInput?.phone).toBe('+6591234567');
 */
import type { PhoneVerifier } from './phone-verifier.port.js';
import type {
  CheckVerificationInput,
  CheckVerificationResult,
  StartVerificationInput,
  StartVerificationResult,
} from './phone-verifier.types.js';

export class FakePhoneVerifier implements PhoneVerifier {
  private nextStartResult: StartVerificationResult = { status: 'sent' };
  private nextCheckResult: CheckVerificationResult = { status: 'verified' };

  lastStartInput: StartVerificationInput | null = null;
  lastCheckInput: CheckVerificationInput | null = null;

  setNextStartResult(result: StartVerificationResult): void {
    this.nextStartResult = result;
  }

  setNextCheckResult(result: CheckVerificationResult): void {
    this.nextCheckResult = result;
  }

  startVerification(input: StartVerificationInput): Promise<StartVerificationResult> {
    this.lastStartInput = input;
    return Promise.resolve(this.nextStartResult);
  }

  checkVerification(input: CheckVerificationInput): Promise<CheckVerificationResult> {
    this.lastCheckInput = input;
    return Promise.resolve(this.nextCheckResult);
  }
}

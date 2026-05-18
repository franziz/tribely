/**
 * Dev/test adapter — logs the SMS verification request instead of sending it.
 * Used when `SMS_TRANSPORT=log` (default in development), so engineers can
 * see the phone + outcome in their console without burning Twilio quota or
 * needing real Twilio credentials.
 *
 * Production MUST set `SMS_TRANSPORT=twilio` (env validation enforces this
 * combined with real Twilio credentials when selected).
 *
 * NOTE: This adapter does NOT enforce the SMS_ALLOWED_COUNTRY_CODES allow-list.
 * Fail-closed enforcement is only meaningful where real money is being spent
 * (i.e., the Twilio adapter). This is intentional dev convenience — document
 * it so future contributors don't add the check here "to be safe".
 *
 * Code-acceptance logic: always returns { status: 'sent' } for startVerification.
 * For checkVerification, returns { status: 'verified' } when code is '000000',
 * else { status: 'invalid' }. This lets local integration flows complete the
 * happy path without a real OTP delivery.
 */
import { logger } from '../middleware/logger.js';
import type { PhoneVerifier } from './phone-verifier.port.js';
import type {
  CheckVerificationInput,
  CheckVerificationResult,
  StartVerificationInput,
  StartVerificationResult,
} from './phone-verifier.types.js';

const DEV_MAGIC_CODE = '000000';

export class LoggingPhoneVerifier implements PhoneVerifier {
  // No `async` — synchronous logger calls. Promise.resolve honors the port
  // contract without triggering `require-await`.
  startVerification(input: StartVerificationInput): Promise<StartVerificationResult> {
    logger.info(
      { event: 'sms.startVerification', phone: input.phone },
      'sms.startVerification (DEV — not actually sent)',
    );
    return Promise.resolve({ status: 'sent' });
  }

  checkVerification(input: CheckVerificationInput): Promise<CheckVerificationResult> {
    const outcome: CheckVerificationResult =
      input.code === DEV_MAGIC_CODE ? { status: 'verified' } : { status: 'invalid' };

    logger.info(
      { event: 'sms.checkVerification', phone: input.phone, outcome: outcome.status },
      'sms.checkVerification (DEV — magic code check only)',
    );
    return Promise.resolve(outcome);
  }
}

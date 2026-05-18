/**
 * Outbound port for phone number (OTP) verification. Lives in `core/sms/`
 * because SMS verification is a cross-cutting concern consumed by multiple
 * bounded contexts (auth's phone verification TRI-16, future account recovery,
 * etc.) — not a property of any one feature.
 *
 * Implementations decide transport:
 * - `LoggingPhoneVerifier` — dev default (SMS_TRANSPORT=log), no real sends.
 * - `TwilioPhoneVerifier` — production adapter (SMS_TRANSPORT=twilio).
 *
 * The port is intentionally narrow: only OTP send + check. Voice / WhatsApp /
 * email channels are explicit out-of-scope for the v1 (TRI-4 non-goals).
 *
 * Refactor trigger: when a second SMS operation lands (e.g. marketing, alerts),
 * split into a primitive `send({ to, body })` port and keep verification as a
 * higher-level use-case-shaped abstraction.
 */
import type {
  CheckVerificationInput,
  CheckVerificationResult,
  StartVerificationInput,
  StartVerificationResult,
} from './phone-verifier.types.js';

export interface PhoneVerifier {
  startVerification(input: StartVerificationInput): Promise<StartVerificationResult>;
  checkVerification(input: CheckVerificationInput): Promise<CheckVerificationResult>;
}

export type {
  CheckVerificationInput,
  CheckVerificationResult,
  StartVerificationInput,
  StartVerificationResult,
};

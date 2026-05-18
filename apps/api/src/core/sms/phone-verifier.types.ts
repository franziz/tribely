/**
 * Result types for the PhoneVerifier port. Discriminated unions of string
 * literals — no enums, matching existing codebase convention.
 *
 * Design decisions (all confirmed with PM):
 * - `rate_limited` collapses user-bucket and account-wide throttle: Twilio
 *   Verify does not differentiate these in the response shape; branching on
 *   sub-codes would leak provider specifics into the port type. Capture
 *   `error.code` in structured logs for ops triage.
 * - No variant carries extra payload beyond `status` (no `verificationId`,
 *   no `retryAfter`). Twilio keys state by phone — consumers don't need a
 *   handle. Extend types in a future ticket if TRI-23 needs countdown UI.
 * - Port methods NEVER throw for transient or Twilio-rejected scenarios;
 *   those become typed results. Methods MAY throw `AppError.validation` if
 *   `PhoneNumber.create()` was bypassed (programmer error).
 */
import type { E164Phone } from './phone-number.js';

export type StartVerificationResult =
  | { status: 'sent' }
  | { status: 'invalid' } // bad E.164 from Twilio's view, or country not in allow-list
  | { status: 'rate_limited' } // any Twilio throttle — user-bucket OR account-wide (collapsed)
  | { status: 'provider_unavailable' }; // 5xx, network error, timeout

export type CheckVerificationResult =
  | { status: 'verified' }
  | { status: 'invalid' } // code wrong (Twilio returns status='pending')
  | { status: 'expired' } // 404 on check: expired / approved-already / max-attempts-reached
  | { status: 'rate_limited' }
  | { status: 'provider_unavailable' };

export interface StartVerificationInput {
  phone: E164Phone;
}

export interface CheckVerificationInput {
  phone: E164Phone;
  code: string;
}

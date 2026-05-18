/**
 * Production adapter backed by Twilio Verify (https://www.twilio.com/verify).
 *
 * THIS IS THE ONLY FILE IN THE REPO ALLOWED TO IMPORT 'twilio'.
 * All other files must consume the PhoneVerifier port instead.
 * An ESLint no-restricted-imports rule (added in TRI-4 commit 3) enforces
 * this boundary at lint time.
 *
 * Design decisions:
 * - Allow-list check fires BEFORE any Twilio SDK call to avoid burning quota
 *   on phone numbers we don't serve. Rejection returns { status: 'invalid' }
 *   and logs WARN — not a throw, because it's a runtime business rule.
 * - rate_limited collapses user-bucket (code 60203 / 60202) AND account-wide
 *   (code 20429) throttle: Twilio does not distinguish these in the response
 *   shape; sub-codes describe what was exceeded, not which bucket.
 * - provider_unavailable is the terminal outcome for 5xx, network errors, and
 *   any non-Twilio-shaped throw by the SDK. No retry/backoff inside the
 *   adapter — that's the consumer's call.
 * - Every call emits a structured log: event, outcome, phoneCountryCode (PDPA-
 *   friendly: first chars of the number, NOT the full E164), and twilioErrorCode
 *   on error paths. requestId is injected by the pino ALS chain automatically.
 * - Channel is hardcoded 'sms'. Voice / WhatsApp / email are out-of-scope per
 *   TRI-4 non-goals.
 * - Twilio client + service SID are captured once at construction.
 */
import twilio from 'twilio';
import type { Twilio } from 'twilio';
import { logger } from '../middleware/logger.js';
import type { PhoneVerifier } from './phone-verifier.port.js';
import type {
  CheckVerificationInput,
  CheckVerificationResult,
  StartVerificationInput,
  StartVerificationResult,
} from './phone-verifier.types.js';

/**
 * Runtime shape of a Twilio REST API error. We depend on the wire shape, not
 * the SDK's `RestException` class identity, because:
 *   - vitest's mock factory and the adapter can resolve `twilio` through
 *     different module instances, breaking `instanceof` checks.
 *   - The `twilio` package's export structure has drifted across versions.
 *   - The wire shape is contractually stable per Twilio's API versioning.
 *
 * Load-bearing fields: `status` (HTTP status, always present). `code` (Twilio
 * sub-code like 60200/60202/60203/20429) is optional because raw 5xx errors
 * may not carry one.
 */
interface TwilioErrorShape {
  readonly status: number;
  readonly code?: number;
  readonly message?: string;
}

function isTwilioRestException(e: unknown): e is TwilioErrorShape {
  if (typeof e !== 'object' || e === null || !('status' in e)) {
    return false;
  }
  const candidate = e as Record<string, unknown>;
  return typeof candidate['status'] === 'number';
}

export interface TwilioPhoneVerifierConfig {
  accountSid: string;
  authToken: string;
  serviceSid: string;
  /** E.164 country code prefixes to allow, e.g. ['+65', '+60']. */
  allowedCountryCodes: string[];
}

/** Extract the country-code prefix of a phone for PDPA-safe logging. */
function phoneCountryCode(phone: string): string {
  // Return up to 4 chars ('+' + up to 3 digits) — enough for ops triage,
  // not enough to identify a person.
  return phone.slice(0, 4);
}

export class TwilioPhoneVerifier implements PhoneVerifier {
  private readonly client: Twilio;
  private readonly serviceSid: string;
  private readonly allowedCountryCodes: string[];

  constructor(config: TwilioPhoneVerifierConfig) {
    this.client = twilio(config.accountSid, config.authToken);
    this.serviceSid = config.serviceSid;
    // Sort longest-first to avoid '+1' matching '+1234' ambiguity.
    this.allowedCountryCodes = [...config.allowedCountryCodes].sort((a, b) => b.length - a.length);
  }

  async startVerification(input: StartVerificationInput): Promise<StartVerificationResult> {
    const { phone } = input;

    // Allow-list gate — fires BEFORE any Twilio call.
    if (!this.isAllowed(phone)) {
      logger.warn(
        { event: 'sms.countryCodeRejected', phoneCountryCode: phoneCountryCode(phone) },
        'sms.startVerification: country code not in allow-list',
      );
      return { status: 'invalid' };
    }

    try {
      await this.client.verify.v2.services(this.serviceSid).verifications.create({
        to: phone,
        channel: 'sms',
      });

      logger.info(
        {
          event: 'sms.startVerification',
          outcome: 'sent',
          phoneCountryCode: phoneCountryCode(phone),
        },
        'sms.startVerification: sent',
      );
      return { status: 'sent' };
    } catch (error: unknown) {
      return this.handleStartError(error, phone);
    }
  }

  async checkVerification(input: CheckVerificationInput): Promise<CheckVerificationResult> {
    const { phone, code } = input;

    // Allow-list gate — fires BEFORE any Twilio call.
    if (!this.isAllowed(phone)) {
      logger.warn(
        { event: 'sms.countryCodeRejected', phoneCountryCode: phoneCountryCode(phone) },
        'sms.checkVerification: country code not in allow-list',
      );
      return { status: 'invalid' };
    }

    try {
      const check = await this.client.verify.v2
        .services(this.serviceSid)
        .verificationChecks.create({
          to: phone,
          code,
        });

      if (check.status === 'approved') {
        logger.info(
          {
            event: 'sms.checkVerification',
            outcome: 'verified',
            phoneCountryCode: phoneCountryCode(phone),
          },
          'sms.checkVerification: verified',
        );
        return { status: 'verified' };
      }

      // status === 'pending' means the code didn't match.
      logger.info(
        {
          event: 'sms.checkVerification',
          outcome: 'invalid',
          phoneCountryCode: phoneCountryCode(phone),
        },
        'sms.checkVerification: code did not match',
      );
      return { status: 'invalid' };
    } catch (error: unknown) {
      return this.handleCheckError(error, phone);
    }
  }

  // --- private helpers ---

  private isAllowed(phone: string): boolean {
    return this.allowedCountryCodes.some((prefix) => phone.startsWith(prefix));
  }

  private handleStartError(error: unknown, phone: string): StartVerificationResult {
    if (isTwilioRestException(error)) {
      const outcome = this.mapStartError(error);
      logger.warn(
        {
          event: 'sms.startVerification',
          outcome: outcome.status,
          phoneCountryCode: phoneCountryCode(phone),
          twilioErrorCode: error.code,
        },
        `sms.startVerification: ${error.message ?? 'unknown error'}`,
      );
      return outcome;
    }

    // Network error, timeout, or unexpected throw.
    const message = error instanceof Error ? error.message : String(error);
    logger.error(
      {
        event: 'sms.startVerification',
        outcome: 'provider_unavailable',
        phoneCountryCode: phoneCountryCode(phone),
      },
      `sms.startVerification: non-Twilio error — ${message}`,
    );
    return { status: 'provider_unavailable' };
  }

  private handleCheckError(error: unknown, phone: string): CheckVerificationResult {
    if (isTwilioRestException(error)) {
      const outcome = this.mapCheckError(error);
      logger.warn(
        {
          event: 'sms.checkVerification',
          outcome: outcome.status,
          phoneCountryCode: phoneCountryCode(phone),
          twilioErrorCode: error.code,
        },
        `sms.checkVerification: ${error.message ?? 'unknown error'}`,
      );
      return outcome;
    }

    const message = error instanceof Error ? error.message : String(error);
    logger.error(
      {
        event: 'sms.checkVerification',
        outcome: 'provider_unavailable',
        phoneCountryCode: phoneCountryCode(phone),
      },
      `sms.checkVerification: non-Twilio error — ${message}`,
    );
    return { status: 'provider_unavailable' };
  }

  private mapStartError(error: TwilioErrorShape): StartVerificationResult {
    // code 60200: invalid parameter (bad E.164 from Twilio's view)
    if (error.code === 60200) {
      return { status: 'invalid' };
    }
    // code 60203: max send attempts (5 OTPs to same number in 10 min)
    if (error.code === 60203) {
      return { status: 'rate_limited' };
    }
    // code 20429: generic too-many-requests (service rate limit OR account-wide)
    if (error.code === 20429) {
      return { status: 'rate_limited' };
    }
    // HTTP 5xx → provider_unavailable
    if (error.status >= 500) {
      return { status: 'provider_unavailable' };
    }
    // Any other 4xx or unknown code → provider_unavailable (safe default)
    return { status: 'provider_unavailable' };
  }

  private mapCheckError(error: TwilioErrorShape): CheckVerificationResult {
    // HTTP 404: verification SID gone — expired, already approved, or max attempts
    if (error.status === 404) {
      return { status: 'expired' };
    }
    // code 60200: invalid parameter (malformed code or phone)
    if (error.code === 60200) {
      return { status: 'invalid' };
    }
    // code 60202: max check attempts (5 wrong codes)
    if (error.code === 60202) {
      return { status: 'rate_limited' };
    }
    // code 20429: generic too-many-requests
    if (error.code === 20429) {
      return { status: 'rate_limited' };
    }
    // HTTP 5xx → provider_unavailable
    if (error.status >= 500) {
      return { status: 'provider_unavailable' };
    }
    // Any other 4xx or unknown code → provider_unavailable
    return { status: 'provider_unavailable' };
  }
}

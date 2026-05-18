import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import { PhoneNumber } from '@/core/sms/phone-number.js';
import type { PhoneVerifier } from '@/core/sms/phone-verifier.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import { phoneVerificationStarted } from '@/features/auth/domain/events/phone-verification-started.event.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';

export interface StartPhoneVerificationInput {
  userId: string;
  rawPhone: string;
}

export interface StartPhoneVerificationResult {
  ok: true;
}

/**
 * Starts phone verification for a user.
 *
 * Orchestrates the OTP send step:
 * 1. Validates the phone number as E.164.
 * 2. Loads the user and checks for an idempotent re-start (same phone already verified).
 * 3. Delegates to PhoneVerifier.startVerification and branches on the typed result.
 * 4. On success, publishes the synthetic `auth.phoneVerificationStarted` event.
 *
 * This use case does NOT mutate the User aggregate. Phone state is committed only
 * after the subsequent check-verification step (SWE-6 / ConfirmPhoneVerificationUseCase).
 */
export class StartPhoneVerificationUseCase {
  constructor(
    private readonly deps: {
      users: UserRepository;
      phoneVerifier: PhoneVerifier;
      events: EventPublisher;
      unitOfWork: UnitOfWork;
      clock: Clock;
    },
  ) {}

  async execute(input: StartPhoneVerificationInput): Promise<StartPhoneVerificationResult> {
    // 1. Parse + validate phone — throws AppError.validation on bad E.164.
    //    Done BEFORE opening the transaction so we fail fast without a DB round-trip.
    const phone = PhoneNumber.create(input.rawPhone);

    return this.deps.unitOfWork.run(async (ctx) => {
      // 2. Load user.
      const user = await this.deps.users.findById(input.userId, ctx);
      if (user === null) {
        throw AppError.notFound('User not found.');
      }

      // 3. Idempotent re-start guard: if the user is already verified with the
      //    exact same phone number, skip the verifier call and return early.
      if (user.phoneVerifiedAt !== null && user.phone?.value === phone.value) {
        return { ok: true as const };
      }

      // 4. Delegate to the PhoneVerifier port and branch on the typed result.
      const result = await this.deps.phoneVerifier.startVerification({ phone: phone.value });

      switch (result.status) {
        case 'sent': {
          const event = phoneVerificationStarted(
            {
              userId: input.userId,
              phoneE164: phone.value,
              startedAt: this.deps.clock.now().toISOString(),
            },
            createId(),
          );
          await this.deps.events.publish(ctx, event);
          return { ok: true as const };
        }
        case 'invalid':
          throw AppError.validation('Invalid phone number for this region.');
        case 'rate_limited':
          throw AppError.unprocessable('SMS rate limit reached. Try again later.', {
            subcode: 'sms_rate_limited',
          });
        case 'provider_unavailable':
          throw AppError.internal('SMS provider unavailable. Try again later.');
      }
    });
  }
}

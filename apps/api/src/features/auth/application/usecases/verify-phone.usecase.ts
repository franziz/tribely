import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import { PhoneNumber } from '@/core/sms/phone-number.js';
import type { PhoneHasher } from '@/core/sms/phone-hasher.port.js';
import type { PhoneVerifier } from '@/core/sms/phone-verifier.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { User } from '@/features/users/domain/entities/user.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';

export interface VerifyPhoneInput {
  userId: string;
  rawPhone: string;
  code: string;
}

export interface VerifyPhoneResult {
  user: User;
}

/**
 * Confirms a phone OTP code and marks the user's phone as verified.
 *
 * Orchestrates the verify step including atomic contested-phone takeover:
 * 1. Validates the phone number as E.164 (pre-tx, fail fast).
 * 2. Opens a transaction and loads the verifying user B.
 * 3. Idempotent re-verify guard: if B already owns this verified phone, returns early.
 * 4. Delegates to PhoneVerifier.checkVerification and branches on the typed result.
 * 5. Checks for an existing verified holder A of the same phone number.
 * 6. Contested takeover: if A exists (A ≠ B), revokes A's verification FIRST
 *    (saves A, publishes A's events), then verifies B. Event ordering is load-bearing —
 *    outbox seq encodes "revoked-then-verified" causal ordering for moderation consumers.
 * 7. Verifies B, saves B, publishes B's events.
 *
 * Critical invariant: A's events are published BEFORE B's events. Do NOT bulk-publish
 * both aggregates' events in a single call — the outbox BIGSERIAL seq would assign
 * ordering non-deterministically.
 */
export class VerifyPhoneUseCase {
  constructor(
    private readonly deps: {
      users: UserRepository;
      phoneVerifier: PhoneVerifier;
      phoneHasher: PhoneHasher;
      events: EventPublisher;
      unitOfWork: UnitOfWork;
      clock: Clock;
    },
  ) {}

  async execute(input: VerifyPhoneInput): Promise<VerifyPhoneResult> {
    // 1. Parse + validate phone — throws AppError.validation on bad E.164.
    //    Done BEFORE opening the transaction so we fail fast without a DB round-trip.
    const phone = PhoneNumber.create(input.rawPhone);

    return this.deps.unitOfWork.run(async (ctx) => {
      // 2. Load the verifying user B.
      const verifierUser = await this.deps.users.findById(input.userId, ctx);
      if (verifierUser === null) {
        throw AppError.notFound('User not found.');
      }

      // 3. Idempotent re-verify guard: if B already owns this verified phone,
      //    skip the verifier call entirely and return the current state.
      if (verifierUser.phoneVerifiedAt !== null && verifierUser.phone?.value === phone.value) {
        return { user: verifierUser };
      }

      // 4. Delegate to the PhoneVerifier port and branch on the typed result.
      const result = await this.deps.phoneVerifier.checkVerification({
        phone: phone.value,
        code: input.code,
      });

      switch (result.status) {
        case 'verified':
          break; // Continue to takeover + verify logic below.
        case 'invalid':
          throw AppError.validation('Invalid code.');
        case 'expired':
          throw AppError.validation('Code expired. Request a new one.');
        case 'rate_limited':
          throw AppError.unprocessable('Too many attempts. Try again later.', {
            subcode: 'sms_rate_limited',
          });
        case 'provider_unavailable':
          throw AppError.internal('SMS provider unavailable. Try again later.');
      }

      // 5. Query for existing holder A of the same verified phone.
      const priorHolder = await this.deps.users.findByVerifiedPhone(phone, ctx);

      // 6. Contested takeover branch: A exists and is a different user from B.
      //    Hash ONCE before the aggregate call — domain stays pure (no hasher inside aggregate).
      //    Publish A's events FIRST to preserve causal ordering in the outbox.
      if (priorHolder !== null && priorHolder.id !== verifierUser.id) {
        const phoneE164Hash = this.deps.phoneHasher.hash(phone.value);
        priorHolder.revokePhoneVerificationOnTakeover(
          verifierUser.id,
          phoneE164Hash,
          this.deps.clock.now(),
        );
        await this.deps.users.save(priorHolder, ctx);
        await this.deps.events.publish(ctx, ...priorHolder.pullEvents());
      }

      // 7. Verify B, save, and publish B's events.
      verifierUser.verifyPhone(phone, this.deps.clock.now());
      await this.deps.users.save(verifierUser, ctx);
      await this.deps.events.publish(ctx, ...verifierUser.pullEvents());

      return { user: verifierUser };
    });
  }
}

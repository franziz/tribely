import type { Consumer } from '@/core/events/consumer.port.js';
import type { SignOutAllUseCase } from '../../application/usecases/sign-out-all.usecase.js';
import {
  PASSWORD_RESET,
  type PasswordResetEvent,
} from '../../domain/events/password-reset.event.js';

export interface SignOutAllOnPasswordResetDeps {
  signOutAll: SignOutAllUseCase;
}

/**
 * After a password is reset, revoke every active refresh token for the user
 * (reason: `password_reset`).
 *
 * Decoupled side-effect: the password change commits independently in
 * `ResetPasswordUseCase`; this consumer reacts to the resulting
 * `auth.passwordReset` event and revokes sessions via `SignOutAllUseCase`.
 *
 * Trade-off vs. inline (joint-commit) revocation: there is a bounded window
 * between the password change committing and this consumer firing during
 * which a stolen refresh token can still mint a fresh access token. The
 * window is bounded by the `OutboxDispatcher` poll interval (seconds in
 * production). The decoupling is deliberate — it lets future side-effects
 * (analytics, "your password was changed" notification email, force-re-key
 * encrypted fields) fan out from the same event without churning the use
 * case, and keeps `Credential` aggregate-level concerns from leaking
 * `RefreshToken`-aggregate writes.
 *
 * Idempotent: `SignOutAllUseCase` is no-op when no active tokens exist, so
 * at-least-once redelivery is safe.
 */
export const signOutAllOnPasswordReset = (
  deps: SignOutAllOnPasswordResetDeps,
): Consumer<PasswordResetEvent> => ({
  name: 'auth.signOutAllOnPasswordReset',
  topic: PASSWORD_RESET,
  async handle(event) {
    await deps.signOutAll.execute({
      userId: event.payload.userId,
      reason: 'password_reset',
    });
  },
});

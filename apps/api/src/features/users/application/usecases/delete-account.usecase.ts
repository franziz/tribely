import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import { sha256Hex } from '@/core/crypto/sha256-hex.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { CredentialRepository } from '@/features/auth/domain/repositories/credential.repository.js';
import type { EmailVerificationTokenRepository } from '@/features/auth/domain/repositories/email-verification-token.repository.js';
import type { PasswordResetTokenRepository } from '@/features/auth/domain/repositories/password-reset-token.repository.js';
import type { RefreshTokenRepository } from '@/features/auth/domain/repositories/refresh-token.repository.js';
import type { RecordAccountDeletionUseCase } from '@/features/audit/application/usecases/record-account-deletion.usecase.js';
import type { HttpAuditLogRepository } from '@/features/audit/domain/repositories/http-audit-log.repository.js';
import type { EventHostPseudonymisationPort } from '@/features/events/application/ports/event-host-pseudonymisation.port.js';
import type { JoinRequestAuthorPseudonymisationPort } from '@/features/join-requests/application/ports/join-request-author-pseudonymisation.port.js';
import type { DeleteSelfieForUserUseCase } from '@/features/selfies/application/usecases/delete-selfie-for-user.usecase.js';
import type { PseudonymiseCheckInsForUserUseCase } from '@/features/check-ins/application/usecases/pseudonymise-check-ins-for-user.usecase.js';
import type { OutboxEventRepository } from '@/core/events/outbox-event.repository.js';
import type { AccountDeletionCascadeScope } from '@/features/audit/domain/repositories/account-deletion-event.repository.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';

export interface DeleteAccountInput {
  userId: string;
}

/**
 * Orchestrates the full PDPA account-deletion cascade for an authenticated user.
 *
 * This is the canonical use case for the "enclosing-UoW as A7-exception" pattern.
 * All sub-use-cases (DeleteSelfieForUserUseCase, PseudonymiseCheckInsForUserUseCase,
 * RecordAccountDeletionUseCase, etc.) receive the caller-supplied TxContext so their
 * writes commit atomically with the main cascade. None open their own UnitOfWork.
 *
 * A7 exception (CLAUDE.md §evidence-integrity): this use case IS the enclosing
 * UnitOfWork for all sub-use-cases. Calling sub-use-cases with the outer ctx is
 * deliberate — not a layering violation.
 *
 * Cascade order:
 *   1. Guard: reject already-tombstoned users with 409.
 *   2. Hard-delete auth tokens (credentials, refresh, email-verify, pw-reset).
 *   3. Delete selfie blob reference (deferred to storage reaper).
 *   4. Pseudonymise post-event check-in rows.
 *   5. Pseudonymise hosted-event hostUserId references.
 *   6. Pseudonymise join-request requesterUserId references.
 *   7. Pseudonymise un-dispatched outbox-event payload + actorUserId column.
 *   8. Hash actorUserId in http_audit_logs rows.
 *   9. Tombstone User aggregate (clears PII, records UserAccountDeletedEvent).
 *  10. Save User + publish domain events.
 *  11. Record account-deletion audit row (required-ctx atomicity contract).
 *
 * Tombstone is intentionally LAST so any sub-step that needs to resolve the
 * original user row via findById can still do so within the same transaction.
 *
 * Failure path: a clean second transaction writes a `failed_rolled_back` audit row
 * so the evidence trail survives the main transaction's rollback. The error is
 * then re-thrown so Hono's onError middleware maps it to the appropriate HTTP status.
 */
export class DeleteAccountUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly userRepository: UserRepository,
    private readonly credentialRepository: CredentialRepository,
    private readonly refreshTokenRepository: RefreshTokenRepository,
    private readonly emailVerificationTokenRepository: EmailVerificationTokenRepository,
    private readonly passwordResetTokenRepository: PasswordResetTokenRepository,
    private readonly deleteSelfieForUser: DeleteSelfieForUserUseCase,
    private readonly pseudonymiseCheckInsForUser: PseudonymiseCheckInsForUserUseCase,
    private readonly eventHostPseudonymisation: EventHostPseudonymisationPort,
    private readonly joinRequestAuthorPseudonymisation: JoinRequestAuthorPseudonymisationPort,
    private readonly outboxRepository: OutboxEventRepository,
    private readonly httpAuditLogRepository: HttpAuditLogRepository,
    private readonly recordAccountDeletion: RecordAccountDeletionUseCase,
    private readonly publisher: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: DeleteAccountInput): Promise<void> {
    const { userId } = input;
    const startedAt = this.clock.now();

    try {
      await this.unitOfWork.run(async (ctx) => {
        // ── 1. Guard: reject already-tombstoned users ──────────────────────────
        const user = await this.userRepository.findById(userId, ctx);
        if (user === null) {
          throw AppError.notFound('User not found');
        }
        if (user.deletedAt !== null) {
          throw AppError.conflict('Account has already been deleted', {
            subcode: 'ACCOUNT_ALREADY_DELETED',
          });
        }

        // ── Common values computed once, reused across cascade steps ───────────
        const requestedAt = this.clock.now();
        // Single pseudonym reused for events.hostUserId + join_requests.requesterUserId
        // so cross-table joins on the pseudonym remain possible forensically.
        const pseudonym = createId();
        // SHA-256 hash of userId — reused for http-audit hashing + audit record.
        const actorHash = sha256Hex(userId);

        // Tracks which cascade scopes completed; appended as each step succeeds.
        // The final array is written to the audit row.
        const cascadeScope: AccountDeletionCascadeScope[] = [];

        // ── 2. Hard-delete auth-side tokens ────────────────────────────────────
        await this.credentialRepository.deleteForUser(userId, ctx);
        cascadeScope.push('credentials');

        await this.refreshTokenRepository.deleteAllForUser(userId, ctx);
        cascadeScope.push('refresh_tokens');

        await this.emailVerificationTokenRepository.deleteAllForUser(userId, ctx);
        cascadeScope.push('email_verification_tokens');

        await this.passwordResetTokenRepository.deleteAllForUser(userId, ctx);
        cascadeScope.push('password_reset_tokens');

        // ── 3. Delete selfie blob reference (storage deferred to reaper) ───────
        await this.deleteSelfieForUser.execute({ userId, reason: 'account-deletion' }, ctx);
        cascadeScope.push('selfies');

        // ── 4. Pseudonymise post-event check-in rows ───────────────────────────
        await this.pseudonymiseCheckInsForUser.execute({ userId }, ctx);
        cascadeScope.push('check_ins');

        // ── 5. Pseudonymise hosted-event hostUserId references ─────────────────
        await this.eventHostPseudonymisation.execute({ userId, pseudonymHostId: pseudonym }, ctx);
        cascadeScope.push('events_hosted');

        // ── 6. Pseudonymise join-request requesterUserId references ────────────
        await this.joinRequestAuthorPseudonymisation.execute(
          { userId, pseudonymAuthorId: pseudonym },
          ctx,
        );
        cascadeScope.push('join_requests_authored');

        // ── 7. Pseudonymise un-dispatched outbox-event payloads ────────────────
        await this.outboxRepository.pseudonymiseUndispatchedPayloadsForUser(userId, pseudonym, ctx);
        cascadeScope.push('outbox_events_redacted');

        // ── 8. Hash actorUserId in http_audit_logs rows ────────────────────────
        await this.httpAuditLogRepository.hashActorForUser(userId, actorHash, ctx);
        cascadeScope.push('http_audit_logs_actor_hashed');

        // ── 9. Tombstone the User aggregate ────────────────────────────────────
        // Intentionally LAST: sub-steps above can still resolve the original
        // user row within this transaction if they need it.
        const completedAt = this.clock.now();
        user.tombstone(completedAt);
        cascadeScope.push('users');

        // ── 10. Save User + publish domain events ──────────────────────────────
        await this.userRepository.save(user, ctx);
        await this.publisher.publish(ctx, ...user.pullEvents());

        // ── 11. Record account-deletion audit row (atomically with cascade) ────
        // Required-ctx two-arg shape: this use case is the enclosing UoW (A7 exception).
        await this.recordAccountDeletion.execute(
          { userId, requestedAt, completedAt, cascadeScope, outcome: 'completed' },
          ctx,
        );
      });
    } catch (err) {
      // Do NOT write a failure audit row for expected 409 conflicts — those
      // are not failures in the cascade, they're guard rejections before the
      // cascade begins.
      if (err instanceof AppError && err.status === 409) {
        throw err;
      }

      // Failure path: open a CLEAN second transaction so the evidence row
      // survives the main transaction's rollback. ALS requestId is still in
      // frame (same HTTP request), so the audit row correlates to the request.
      await this.unitOfWork.run(async (ctx2) => {
        await this.recordAccountDeletion.execute(
          {
            userId,
            requestedAt: startedAt,
            completedAt: this.clock.now(),
            cascadeScope: [],
            outcome: 'failed_rolled_back',
            failureReason: err instanceof Error ? err.message : String(err),
          },
          ctx2,
        );
      });

      throw err;
    }
  }
}

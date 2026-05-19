import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { sha256Hex } from '@/core/crypto/sha256-hex.js';
import { FakeEventPublisher, FakeUnitOfWork, FixedClock, TEST_TX } from '@/core/testing/fakes.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { DomainEvent } from '@/core/events/domain-event.js';
import type { User } from '../../domain/entities/user.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import type { CredentialRepository } from '@/features/auth/domain/repositories/credential.repository.js';
import type { RefreshTokenRepository } from '@/features/auth/domain/repositories/refresh-token.repository.js';
import type { EmailVerificationTokenRepository } from '@/features/auth/domain/repositories/email-verification-token.repository.js';
import type { PasswordResetTokenRepository } from '@/features/auth/domain/repositories/password-reset-token.repository.js';
import type { DeleteSelfieForUserUseCase } from '@/features/selfies/application/usecases/delete-selfie-for-user.usecase.js';
import type { PseudonymiseCheckInsForUserUseCase } from '@/features/check-ins/application/usecases/pseudonymise-check-ins-for-user.usecase.js';
import type { EventHostPseudonymisationPort } from '@/features/events/application/ports/event-host-pseudonymisation.port.js';
import type { JoinRequestAuthorPseudonymisationPort } from '@/features/join-requests/application/ports/join-request-author-pseudonymisation.port.js';
import type { OutboxEventRepository } from '@/core/events/outbox-event.repository.js';
import type { HttpAuditLogRepository } from '@/features/audit/domain/repositories/http-audit-log.repository.js';
import type {
  RecordAccountDeletionInput,
  RecordAccountDeletionUseCase,
} from '@/features/audit/application/usecases/record-account-deletion.usecase.js';
import type { AccountDeletionCascadeScope } from '@/features/audit/domain/repositories/account-deletion-event.repository.js';
import { DeleteAccountUseCase } from './delete-account.usecase.js';

// ---------------------------------------------------------------------------
// Minimal fakes — local to this test file, NOT re-exported.
// Cross-feature fakes (auth/events/join-requests/audit) are never imported;
// all collaborators are satisfied by inline anonymous objects or vi.fn() stubs.
// ---------------------------------------------------------------------------

class FakeUserRepository implements UserRepository {
  private users = new Map<string, User>();

  seed(user: User): void {
    this.users.set(user.id, user);
  }

  async findById(id: string): Promise<User | null> {
    return this.users.get(id) ?? null;
  }

  async findByEmail(): Promise<User | null> {
    return null;
  }

  async findByVerifiedPhone(): Promise<User | null> {
    return null;
  }

  async save(user: User): Promise<void> {
    this.users.set(user.id, user);
  }
}

class FakeCredentialRepository implements Pick<CredentialRepository, 'deleteForUser'> {
  calls: string[] = [];
  async deleteForUser(userId: string, _ctx: TxContext): Promise<void> {
    this.calls.push(userId);
  }
}

class FakeRefreshTokenRepository implements Pick<RefreshTokenRepository, 'deleteAllForUser'> {
  calls: string[] = [];
  async deleteAllForUser(userId: string, _ctx: TxContext): Promise<number> {
    this.calls.push(userId);
    return 0;
  }
}

class FakeEmailVerificationTokenRepository implements Pick<
  EmailVerificationTokenRepository,
  'deleteAllForUser'
> {
  calls: string[] = [];
  async deleteAllForUser(userId: string, _ctx: TxContext): Promise<number> {
    this.calls.push(userId);
    return 0;
  }
}

class FakePasswordResetTokenRepository implements Pick<
  PasswordResetTokenRepository,
  'deleteAllForUser'
> {
  calls: string[] = [];
  async deleteAllForUser(userId: string, _ctx: TxContext): Promise<number> {
    this.calls.push(userId);
    return 0;
  }
}

class FakeDeleteSelfieForUser implements Pick<DeleteSelfieForUserUseCase, 'execute'> {
  calls: Array<{ userId: string; reason: string }> = [];
  async execute(input: { userId: string; reason: string }, _ctx: TxContext): Promise<void> {
    this.calls.push(input);
  }
}

class FakePseudonymiseCheckInsForUser implements Pick<
  PseudonymiseCheckInsForUserUseCase,
  'execute'
> {
  calls: string[] = [];
  async execute(
    input: { userId: string },
    _ctx: TxContext,
  ): Promise<{ pseudonymisedReports: number; deletedReports: number }> {
    this.calls.push(input.userId);
    return { pseudonymisedReports: 0, deletedReports: 0 };
  }
}

class FakeEventHostPseudonymisation implements EventHostPseudonymisationPort {
  calls: Array<{ userId: string; pseudonymHostId: string }> = [];
  async execute(
    input: { userId: string; pseudonymHostId: string },
    _ctx: TxContext,
  ): Promise<{ updatedCount: number }> {
    this.calls.push(input);
    return { updatedCount: 0 };
  }
}

class FakeJoinRequestAuthorPseudonymisation implements JoinRequestAuthorPseudonymisationPort {
  calls: Array<{ userId: string; pseudonymAuthorId: string }> = [];
  async execute(
    input: { userId: string; pseudonymAuthorId: string },
    _ctx: TxContext,
  ): Promise<{ updatedCount: number }> {
    this.calls.push(input);
    return { updatedCount: 0 };
  }
}

class FakeOutboxEventRepository implements OutboxEventRepository {
  calls: string[] = [];
  async pseudonymiseUndispatchedPayloadsForUser(
    userId: string,
    _pseudonym: string,
    _ctx: TxContext,
  ): Promise<number> {
    this.calls.push(userId);
    return 0;
  }
}

class FakeHttpAuditLogRepository implements Pick<HttpAuditLogRepository, 'hashActorForUser'> {
  calls: Array<{ userId: string; actorHash: string }> = [];
  async hashActorForUser(userId: string, actorHash: string, _ctx: TxContext): Promise<number> {
    this.calls.push({ userId, actorHash });
    return 0;
  }
}

class FakeRecordAccountDeletion {
  readonly calls: Array<{ input: RecordAccountDeletionInput; ctx: TxContext }> = [];
  async execute(input: RecordAccountDeletionInput, ctx: TxContext): Promise<void> {
    this.calls.push({ input, ctx });
  }
}

// ---------------------------------------------------------------------------
// Helpers to build a live User aggregate (not tombstoned)
// ---------------------------------------------------------------------------

/** Builds a minimal active User via the static register factory. */
const buildActiveUser = async (id: string): Promise<User> => {
  const { User } = await import('../../domain/entities/user.js');
  const { Email } = await import('../../domain/value-objects/email.js');
  const { DisplayName } = await import('../../domain/value-objects/display-name.js');
  return User.register({
    id,
    email: Email.create(`${id}@test.local`),
    displayName: DisplayName.create('Test User'),
    now: new Date('2026-01-01T00:00:00Z'),
  });
};

/** Builds an already-tombstoned User. */
const buildTombstonedUser = async (id: string): Promise<User> => {
  const user = await buildActiveUser(id);
  user.tombstone(new Date('2026-01-02T00:00:00Z'));
  return user;
};

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

describe('DeleteAccountUseCase', () => {
  const FIXED_TIME = new Date('2026-05-19T10:00:00Z');
  const USER_ID = 'user_delete_test_01';

  let uow: FakeUnitOfWork;
  let userRepo: FakeUserRepository;
  let credentialRepo: FakeCredentialRepository;
  let refreshTokenRepo: FakeRefreshTokenRepository;
  let emailVerificationTokenRepo: FakeEmailVerificationTokenRepository;
  let passwordResetTokenRepo: FakePasswordResetTokenRepository;
  let deleteSelfieForUser: FakeDeleteSelfieForUser;
  let pseudonymiseCheckIns: FakePseudonymiseCheckInsForUser;
  let eventHostPseudonymisation: FakeEventHostPseudonymisation;
  let joinRequestAuthorPseudonymisation: FakeJoinRequestAuthorPseudonymisation;
  let outboxRepo: FakeOutboxEventRepository;
  let httpAuditLogRepo: FakeHttpAuditLogRepository;
  let recordAccountDeletion: FakeRecordAccountDeletion;
  let publisher: FakeEventPublisher;
  let clock: FixedClock;
  let useCase: DeleteAccountUseCase;

  beforeEach(() => {
    uow = new FakeUnitOfWork();
    userRepo = new FakeUserRepository();
    credentialRepo = new FakeCredentialRepository();
    refreshTokenRepo = new FakeRefreshTokenRepository();
    emailVerificationTokenRepo = new FakeEmailVerificationTokenRepository();
    passwordResetTokenRepo = new FakePasswordResetTokenRepository();
    deleteSelfieForUser = new FakeDeleteSelfieForUser();
    pseudonymiseCheckIns = new FakePseudonymiseCheckInsForUser();
    eventHostPseudonymisation = new FakeEventHostPseudonymisation();
    joinRequestAuthorPseudonymisation = new FakeJoinRequestAuthorPseudonymisation();
    outboxRepo = new FakeOutboxEventRepository();
    httpAuditLogRepo = new FakeHttpAuditLogRepository();
    recordAccountDeletion = new FakeRecordAccountDeletion();
    publisher = new FakeEventPublisher();
    clock = new FixedClock(FIXED_TIME);

    useCase = new DeleteAccountUseCase(
      uow,
      userRepo as unknown as UserRepository,
      credentialRepo as unknown as CredentialRepository,
      refreshTokenRepo as unknown as RefreshTokenRepository,
      emailVerificationTokenRepo as unknown as EmailVerificationTokenRepository,
      passwordResetTokenRepo as unknown as PasswordResetTokenRepository,
      deleteSelfieForUser as unknown as DeleteSelfieForUserUseCase,
      pseudonymiseCheckIns as unknown as PseudonymiseCheckInsForUserUseCase,
      eventHostPseudonymisation,
      joinRequestAuthorPseudonymisation,
      outboxRepo,
      httpAuditLogRepo as unknown as HttpAuditLogRepository,
      recordAccountDeletion as unknown as RecordAccountDeletionUseCase,
      publisher,
      clock,
    );
  });

  // ─── Happy path ───────────────────────────────────────────────────────────

  describe('happy path', () => {
    it('calls every cascade collaborator exactly once with the correct userId', async () => {
      const user = await buildActiveUser(USER_ID);
      userRepo.seed(user);

      await useCase.execute({ userId: USER_ID });

      expect(credentialRepo.calls).toEqual([USER_ID]);
      expect(refreshTokenRepo.calls).toEqual([USER_ID]);
      expect(emailVerificationTokenRepo.calls).toEqual([USER_ID]);
      expect(passwordResetTokenRepo.calls).toEqual([USER_ID]);
      expect(deleteSelfieForUser.calls).toHaveLength(1);
      expect(deleteSelfieForUser.calls[0]?.userId).toBe(USER_ID);
      expect(deleteSelfieForUser.calls[0]?.reason).toBe('account-deletion');
      expect(pseudonymiseCheckIns.calls).toEqual([USER_ID]);
      expect(eventHostPseudonymisation.calls).toHaveLength(1);
      expect(eventHostPseudonymisation.calls[0]?.userId).toBe(USER_ID);
      expect(joinRequestAuthorPseudonymisation.calls).toHaveLength(1);
      expect(joinRequestAuthorPseudonymisation.calls[0]?.userId).toBe(USER_ID);
      expect(outboxRepo.calls).toEqual([USER_ID]);
      expect(httpAuditLogRepo.calls).toHaveLength(1);
      expect(httpAuditLogRepo.calls[0]?.userId).toBe(USER_ID);
    });

    it('uses the same pseudonym for eventHost and joinRequestAuthor pseudonymisations', async () => {
      const user = await buildActiveUser(USER_ID);
      userRepo.seed(user);

      await useCase.execute({ userId: USER_ID });

      const eventPseudonym = eventHostPseudonymisation.calls[0]?.pseudonymHostId;
      const joinRequestPseudonym = joinRequestAuthorPseudonymisation.calls[0]?.pseudonymAuthorId;
      expect(eventPseudonym).toBeDefined();
      expect(eventPseudonym).toBe(joinRequestPseudonym);
    });

    it('hashes actorUserId in http_audit_logs using sha256Hex(userId)', async () => {
      const user = await buildActiveUser(USER_ID);
      userRepo.seed(user);

      await useCase.execute({ userId: USER_ID });

      const expectedHash = sha256Hex(USER_ID);
      expect(httpAuditLogRepo.calls[0]?.actorHash).toBe(expectedHash);
    });

    it('tombstones the User (sets deletedAt, clears PII)', async () => {
      const user = await buildActiveUser(USER_ID);
      userRepo.seed(user);

      await useCase.execute({ userId: USER_ID });

      // The user was saved back — it should now have deletedAt set.
      const savedUser = await userRepo.findById(USER_ID);
      expect(savedUser?.deletedAt).not.toBeNull();
    });

    it('publishes UserAccountDeletedEvent via the outbox publisher', async () => {
      const user = await buildActiveUser(USER_ID);
      userRepo.seed(user);

      await useCase.execute({ userId: USER_ID });

      const publishedTypes = publisher.published.map((e: DomainEvent) => e.type);
      expect(publishedTypes).toContain('users.userAccountDeleted');
    });

    it('writes the audit row with outcome=completed and all 11 cascadeScope values', async () => {
      const user = await buildActiveUser(USER_ID);
      userRepo.seed(user);

      await useCase.execute({ userId: USER_ID });

      expect(recordAccountDeletion.calls).toHaveLength(1);
      const auditInput = recordAccountDeletion.calls[0]?.input;
      expect(auditInput?.outcome).toBe('completed');
      expect(auditInput?.userId).toBe(USER_ID);

      const expectedScopes: AccountDeletionCascadeScope[] = [
        'credentials',
        'refresh_tokens',
        'email_verification_tokens',
        'password_reset_tokens',
        'selfies',
        'check_ins',
        'events_hosted',
        'join_requests_authored',
        'outbox_events_redacted',
        'http_audit_logs_actor_hashed',
        'users',
      ];
      expect(auditInput?.cascadeScope).toEqual(expectedScopes);
      expect(auditInput?.cascadeScope).toHaveLength(11);
    });

    it('writes the audit row inside the same transaction context (A7 exception)', async () => {
      const user = await buildActiveUser(USER_ID);
      userRepo.seed(user);

      await useCase.execute({ userId: USER_ID });

      // FakeUnitOfWork passes TEST_TX — verify the audit call received it.
      expect(recordAccountDeletion.calls[0]?.ctx).toBe(TEST_TX);
    });
  });

  // ─── 409 already-tombstoned ───────────────────────────────────────────────

  describe('409 already-tombstoned', () => {
    it('throws AppError.conflict with ACCOUNT_ALREADY_DELETED subcode when user is tombstoned', async () => {
      const user = await buildTombstonedUser(USER_ID);
      userRepo.seed(user);

      await expect(useCase.execute({ userId: USER_ID })).rejects.toMatchObject({
        code: 'CONFLICT',
        status: 409,
        details: { subcode: 'ACCOUNT_ALREADY_DELETED' },
      });
    });

    it('does NOT write a failure audit row on a 409 guard rejection', async () => {
      const user = await buildTombstonedUser(USER_ID);
      userRepo.seed(user);

      await useCase.execute({ userId: USER_ID }).catch(() => null);

      // No audit row should be written — 409 is a guard rejection, not a failure.
      expect(recordAccountDeletion.calls).toHaveLength(0);
    });

    it('returns 409 on a second call after successful deletion', async () => {
      const user = await buildActiveUser(USER_ID);
      userRepo.seed(user);

      // First call — succeeds.
      await useCase.execute({ userId: USER_ID });

      // Second call — user is now tombstoned.
      await expect(useCase.execute({ userId: USER_ID })).rejects.toMatchObject({
        status: 409,
        details: { subcode: 'ACCOUNT_ALREADY_DELETED' },
      });
    });
  });

  // ─── Failure path ─────────────────────────────────────────────────────────

  describe('failure path', () => {
    it('writes a failed_rolled_back audit row in a clean second tx when a cascade step throws', async () => {
      const user = await buildActiveUser(USER_ID);
      userRepo.seed(user);

      const boom = new Error('constraint violation on events table');
      pseudonymiseCheckIns.execute = vi.fn().mockRejectedValue(boom);

      await expect(useCase.execute({ userId: USER_ID })).rejects.toThrow(boom.message);

      // Exactly one audit row — the failure row from the second clean tx.
      expect(recordAccountDeletion.calls).toHaveLength(1);
      const auditInput = recordAccountDeletion.calls[0]?.input;
      expect(auditInput?.outcome).toBe('failed_rolled_back');
      expect(auditInput?.failureReason).toBe(boom.message);
      expect(auditInput?.cascadeScope).toEqual([]);
    });

    it('re-throws the original error after writing the failure audit row', async () => {
      const user = await buildActiveUser(USER_ID);
      userRepo.seed(user);

      const boom = new AppError('INTERNAL', 'db exploded', 500);
      outboxRepo.pseudonymiseUndispatchedPayloadsForUser = vi.fn().mockRejectedValue(boom);

      await expect(useCase.execute({ userId: USER_ID })).rejects.toBe(boom);
    });

    it('failure audit row uses a fresh second tx (different call to uow.run)', async () => {
      const user = await buildActiveUser(USER_ID);
      userRepo.seed(user);

      const boom = new Error('mid-cascade failure');
      emailVerificationTokenRepo.deleteAllForUser = vi.fn().mockRejectedValue(boom);

      // Spy on uow.run to count invocations.
      const runSpy = vi.spyOn(uow, 'run');

      await useCase.execute({ userId: USER_ID }).catch(() => null);

      // First call: main cascade tx (throws). Second call: failure audit tx.
      expect(runSpy).toHaveBeenCalledTimes(2);
    });
  });
});

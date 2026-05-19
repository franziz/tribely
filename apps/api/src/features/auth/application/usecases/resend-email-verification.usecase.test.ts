import { beforeEach, describe, expect, it } from 'vitest';
import { FakeEmailSender } from '@/core/email/fake-email-sender.js';
import { User } from '@/features/users/domain/entities/user.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { IssueEmailVerificationUseCase } from './issue-email-verification.usecase.js';
import { ResendEmailVerificationUseCase } from './resend-email-verification.usecase.js';
import {
  FakeEmailVerificationTokenRepository,
  FakeEventPublisher,
  FakeUnitOfWork,
  FakeUserRepository,
  FakeVerificationCodeHasher,
  FixedClock,
} from './fakes.js';

const buildUser = (verifiedAt: Date | null = null): User =>
  User.rehydrate({
    id: 'user_1',
    email: Email.create('alice@example.com'),
    displayName: DisplayName.create('Alice'),
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-01T00:00:00Z'),
    emailVerifiedAt: verifiedAt,
    bio: null,
    avatarUrl: null,
    languages: [],
    interests: [],
    currentCity: null,
    travelerType: null,
    phone: null,
    phoneVerifiedAt: null,
    selfieStatus: null,
    selfieAttemptCount: 0,
    selfieLastFailureCategory: null,
    selfieAppealLockedAt: null,
  });

describe('ResendEmailVerificationUseCase', () => {
  let users: FakeUserRepository;
  let email: FakeEmailSender;
  let useCase: ResendEmailVerificationUseCase;

  beforeEach(() => {
    users = new FakeUserRepository();
    const tokens = new FakeEmailVerificationTokenRepository();
    const events = new FakeEventPublisher();
    email = new FakeEmailSender();
    const hasher = new FakeVerificationCodeHasher();
    hasher.enqueue('482917');
    const clock = new FixedClock(new Date('2026-02-02T00:00:00Z'));
    const issue = new IssueEmailVerificationUseCase(
      new FakeUnitOfWork(),
      users,
      tokens,
      hasher,
      events,
      email,
      clock,
      48 * 60 * 60,
    );
    useCase = new ResendEmailVerificationUseCase(users, issue);
  });

  it('issues a new code via the underlying use case', async () => {
    users.put(buildUser());
    await useCase.execute({ userId: 'user_1' });
    expect(email.sent).toEqual([{ kind: 'verification', to: 'alice@example.com', code: '482917' }]);
  });

  it('404 if user does not exist', async () => {
    await expect(useCase.execute({ userId: 'ghost' })).rejects.toMatchObject({
      code: 'NOT_FOUND',
    });
  });

  it('409 if user is already verified', async () => {
    users.put(buildUser(new Date('2026-01-15T00:00:00Z')));
    await expect(useCase.execute({ userId: 'user_1' })).rejects.toMatchObject({
      code: 'CONFLICT',
    });
    expect(email.sent).toHaveLength(0);
  });
});

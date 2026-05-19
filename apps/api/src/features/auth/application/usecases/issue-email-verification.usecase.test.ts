import { beforeEach, describe, expect, it } from 'vitest';
import { FakeEmailSender } from '@/core/email/fake-email-sender.js';
import { User } from '@/features/users/domain/entities/user.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { EMAIL_VERIFICATION_INVALIDATED } from '../../domain/events/email-verification-invalidated.event.js';
import { EMAIL_VERIFICATION_ISSUED } from '../../domain/events/email-verification-issued.event.js';
import { IssueEmailVerificationUseCase } from './issue-email-verification.usecase.js';
import {
  FakeEmailVerificationTokenRepository,
  FakeEventPublisher,
  FakeUnitOfWork,
  FakeUserRepository,
  FakeVerificationCodeHasher,
  FixedClock,
} from './fakes.js';

const TTL_SECONDS = 48 * 60 * 60;

const buildUser = (overrides: { verifiedAt?: Date | null } = {}): User => {
  const now = new Date('2026-01-01T00:00:00Z');
  const verifiedAt = overrides.verifiedAt ?? null;
  return User.rehydrate({
    id: 'user_1',
    email: Email.create('alice@example.com'),
    displayName: DisplayName.create('Alice'),
    createdAt: now,
    updatedAt: now,
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
    deletedAt: null,
  });
};

describe('IssueEmailVerificationUseCase', () => {
  let users: FakeUserRepository;
  let tokens: FakeEmailVerificationTokenRepository;
  let events: FakeEventPublisher;
  let email: FakeEmailSender;
  let hasher: FakeVerificationCodeHasher;
  let clock: FixedClock;
  let useCase: IssueEmailVerificationUseCase;

  beforeEach(() => {
    users = new FakeUserRepository();
    tokens = new FakeEmailVerificationTokenRepository();
    events = new FakeEventPublisher();
    email = new FakeEmailSender();
    hasher = new FakeVerificationCodeHasher();
    clock = new FixedClock(new Date('2026-02-02T00:00:00Z'));
    useCase = new IssueEmailVerificationUseCase(
      new FakeUnitOfWork(),
      users,
      tokens,
      hasher,
      events,
      email,
      clock,
      TTL_SECONDS,
    );
  });

  it('persists a token + sends email to the user', async () => {
    users.put(buildUser());
    hasher.enqueue('482917');

    await useCase.execute({ userId: 'user_1' });

    const persisted = tokens.all();
    expect(persisted).toHaveLength(1);
    const token = persisted[0];
    if (!token) throw new Error('expected token');
    expect(token.codeHash).toBe('h:482917');
    expect(token.expiresAt.getTime() - clock.now().getTime()).toBe(TTL_SECONDS * 1000);

    expect(email.sent).toHaveLength(1);
    expect(email.sent[0]).toMatchObject({
      to: 'alice@example.com',
      subject: 'Your Tribely verification code',
    });
    expect(email.sent[0]?.text).toContain('482917');
    expect(email.sent[0]?.html).toContain('482917');

    expect(events.published.map((e) => e.type)).toContain(EMAIL_VERIFICATION_ISSUED);
  });

  it('invalidates an existing open token before issuing a new one', async () => {
    users.put(buildUser());
    hasher.enqueue('111111', '222222');

    await useCase.execute({ userId: 'user_1' });
    await useCase.execute({ userId: 'user_1' });

    const all = tokens.all();
    expect(all).toHaveLength(2);
    const old = all.find((t) => t.codeHash === 'h:111111');
    const fresh = all.find((t) => t.codeHash === 'h:222222');
    expect(old?.invalidated).toBe(true);
    expect(fresh?.invalidated).toBe(false);

    const reasons = events.published
      .filter((e) => e.type === EMAIL_VERIFICATION_INVALIDATED)
      .map((e) => (e.payload as { reason: string }).reason);
    expect(reasons).toContain('replaced');

    expect(email.sent.map((s) => s.to)).toEqual(['alice@example.com', 'alice@example.com']);
    expect(email.sent[0]?.text).toContain('111111');
    expect(email.sent[1]?.text).toContain('222222');
  });

  it('no-ops if user is already verified', async () => {
    users.put(buildUser({ verifiedAt: new Date('2026-01-15T00:00:00Z') }));

    await useCase.execute({ userId: 'user_1' });

    expect(tokens.all()).toHaveLength(0);
    expect(email.sent).toHaveLength(0);
  });

  it('no-ops if user does not exist', async () => {
    await useCase.execute({ userId: 'ghost' });

    expect(tokens.all()).toHaveLength(0);
    expect(email.sent).toHaveLength(0);
  });
});

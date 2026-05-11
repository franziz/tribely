import { beforeEach, describe, expect, it } from 'vitest';
import { FakeEmailSender } from '@/core/email/__test__/fake-email-sender.js';
import { User } from '@/features/users/domain/entities/user.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { PASSWORD_RESET_REQUESTED } from '../../domain/events/password-reset-requested.event.js';
import { PASSWORD_RESET_TOKEN_INVALIDATED } from '../../domain/events/password-reset-token-invalidated.event.js';
import { RequestPasswordResetUseCase } from './request-password-reset.usecase.js';
import {
  FakeEventPublisher,
  FakeLogger,
  FakePasswordResetTokenRepository,
  FakeUnitOfWork,
  FakeUserRepository,
  FakeVerificationCodeHasher,
  FixedClock,
} from './__test__/fakes.js';

const TTL_SECONDS = 24 * 60 * 60;

const buildUser = (overrides: { verifiedAt?: Date | null } = {}): User => {
  const now = new Date('2026-01-01T00:00:00Z');
  const verifiedAt = overrides.verifiedAt === undefined ? now : overrides.verifiedAt;
  return User.rehydrate({
    id: 'user_1',
    email: Email.create('alice@example.com'),
    displayName: DisplayName.create('Alice'),
    createdAt: now,
    updatedAt: now,
    emailVerifiedAt: verifiedAt,
  });
};

describe('RequestPasswordResetUseCase', () => {
  let users: FakeUserRepository;
  let tokens: FakePasswordResetTokenRepository;
  let events: FakeEventPublisher;
  let email: FakeEmailSender;
  let hasher: FakeVerificationCodeHasher;
  let clock: FixedClock;
  let log: FakeLogger;
  let useCase: RequestPasswordResetUseCase;

  beforeEach(() => {
    users = new FakeUserRepository();
    tokens = new FakePasswordResetTokenRepository();
    events = new FakeEventPublisher();
    email = new FakeEmailSender();
    hasher = new FakeVerificationCodeHasher();
    clock = new FixedClock(new Date('2026-02-02T00:00:00Z'));
    log = new FakeLogger();
    useCase = new RequestPasswordResetUseCase(
      new FakeUnitOfWork(),
      users,
      tokens,
      hasher,
      events,
      email,
      clock,
      log,
      TTL_SECONDS,
    );
  });

  it('persists a token + sends email to a verified user', async () => {
    users.put(buildUser());
    hasher.enqueue('482917');

    await useCase.execute({ email: 'alice@example.com' });

    const persisted = tokens.all();
    expect(persisted).toHaveLength(1);
    const token = persisted[0];
    if (!token) throw new Error('expected token');
    expect(token.codeHash).toBe('h:482917');
    expect(token.expiresAt.getTime() - clock.now().getTime()).toBe(TTL_SECONDS * 1000);

    expect(email.sent).toEqual([
      { kind: 'password-reset', to: 'alice@example.com', code: '482917' },
    ]);

    expect(events.published.map((e) => e.type)).toContain(PASSWORD_RESET_REQUESTED);
  });

  it('invalidates an existing open token before issuing a new one', async () => {
    users.put(buildUser());
    hasher.enqueue('111111', '222222');

    await useCase.execute({ email: 'alice@example.com' });
    await useCase.execute({ email: 'alice@example.com' });

    const all = tokens.all();
    expect(all).toHaveLength(2);
    const old = all.find((t) => t.codeHash === 'h:111111');
    const fresh = all.find((t) => t.codeHash === 'h:222222');
    expect(old?.invalidated).toBe(true);
    expect(fresh?.invalidated).toBe(false);

    const reasons = events.published
      .filter((e) => e.type === PASSWORD_RESET_TOKEN_INVALIDATED)
      .map((e) => (e.payload as { reason: string }).reason);
    expect(reasons).toContain('replaced');

    expect(email.sent.map((s) => s.code)).toEqual(['111111', '222222']);
  });

  it('silently no-ops + logs when email is not registered', async () => {
    await useCase.execute({ email: 'ghost@example.com' });

    expect(tokens.all()).toHaveLength(0);
    expect(email.sent).toHaveLength(0);
    expect(events.published).toHaveLength(0);

    const skip = log.logs.find((l) => l.payload.event === 'password_reset.silent_skip');
    expect(skip?.level).toBe('info');
    expect(skip?.payload).toMatchObject({ reason: 'user_not_found' });
  });

  it('silently no-ops + logs when user has not verified their email', async () => {
    users.put(buildUser({ verifiedAt: null }));

    await useCase.execute({ email: 'alice@example.com' });

    expect(tokens.all()).toHaveLength(0);
    expect(email.sent).toHaveLength(0);
    expect(events.published).toHaveLength(0);

    const skip = log.logs.find((l) => l.payload.event === 'password_reset.silent_skip');
    expect(skip?.level).toBe('info');
    expect(skip?.payload).toMatchObject({ reason: 'email_not_verified', userId: 'user_1' });
  });

  it('rejects malformed email at the domain boundary', async () => {
    await expect(useCase.execute({ email: 'not-an-email' })).rejects.toBeDefined();
    expect(tokens.all()).toHaveLength(0);
    expect(email.sent).toHaveLength(0);
  });
});

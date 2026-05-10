import { beforeEach, describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { User } from '@/features/users/domain/entities/user.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { EmailVerificationToken } from '../../domain/entities/email-verification-token.js';
import { EMAIL_VERIFICATION_CONSUMED } from '../../domain/events/email-verification-consumed.event.js';
import { EMAIL_VERIFICATION_INVALIDATED } from '../../domain/events/email-verification-invalidated.event.js';
import { USER_EMAIL_VERIFIED } from '@/features/users/domain/events/user-email-verified.event.js';
import { VerifyEmailUseCase } from './verify-email.usecase.js';
import {
  FakeEmailVerificationTokenRepository,
  FakeEventPublisher,
  FakeUnitOfWork,
  FakeUserRepository,
  FakeVerificationCodeHasher,
  FixedClock,
} from './__test__/fakes.js';

const buildUser = (verifiedAt: Date | null = null): User =>
  User.rehydrate({
    id: 'user_1',
    email: Email.create('alice@example.com'),
    displayName: DisplayName.create('Alice'),
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-01T00:00:00Z'),
    emailVerifiedAt: verifiedAt,
  });

const buildToken = (
  overrides: { codeHash?: string; expiresAt?: Date; invalidated?: boolean } = {},
): EmailVerificationToken => {
  const issuedAt = new Date('2026-02-01T00:00:00Z');
  return EmailVerificationToken.rehydrate({
    id: 'tok_1',
    userId: 'user_1',
    codeHash: overrides.codeHash ?? 'h:482917',
    issuedAt,
    expiresAt: overrides.expiresAt ?? new Date('2026-02-03T00:00:00Z'),
    consumedAt: null,
    attempts: 0,
    invalidated: overrides.invalidated ?? false,
  });
};

describe('VerifyEmailUseCase', () => {
  let users: FakeUserRepository;
  let tokens: FakeEmailVerificationTokenRepository;
  let events: FakeEventPublisher;
  let hasher: FakeVerificationCodeHasher;
  let clock: FixedClock;
  let useCase: VerifyEmailUseCase;

  beforeEach(() => {
    users = new FakeUserRepository();
    tokens = new FakeEmailVerificationTokenRepository();
    events = new FakeEventPublisher();
    hasher = new FakeVerificationCodeHasher();
    clock = new FixedClock(new Date('2026-02-02T00:00:00Z'));
    useCase = new VerifyEmailUseCase(new FakeUnitOfWork(), users, tokens, hasher, events, clock);
  });

  it('verifies the user + consumes the token + publishes events', async () => {
    users.put(buildUser());
    tokens.put(buildToken());

    const result = await useCase.execute({ userId: 'user_1', code: '482917' });

    expect(result.user.isEmailVerified()).toBe(true);
    expect(result.user.emailVerifiedAt).toEqual(clock.now());

    const stored = tokens.all()[0];
    expect(stored?.isConsumed()).toBe(true);

    const types = events.published.map((e) => e.type);
    expect(types).toContain(EMAIL_VERIFICATION_CONSUMED);
    expect(types).toContain(USER_EMAIL_VERIFIED);
  });

  it('idempotent — already verified user returns success without touching token', async () => {
    users.put(buildUser(new Date('2026-01-15T00:00:00Z')));
    tokens.put(buildToken());

    const result = await useCase.execute({ userId: 'user_1', code: '482917' });

    expect(result.user.isEmailVerified()).toBe(true);
    expect(events.published).toHaveLength(0);
    expect(tokens.all()[0]?.isConsumed()).toBe(false);
  });

  it('400 when no open token', async () => {
    users.put(buildUser());

    await expect(useCase.execute({ userId: 'user_1', code: '482917' })).rejects.toMatchObject({
      code: 'VALIDATION_ERROR',
    });
  });

  it('400 when token expired', async () => {
    users.put(buildUser());
    tokens.put(buildToken({ expiresAt: new Date('2026-02-01T12:00:00Z') }));

    await expect(useCase.execute({ userId: 'user_1', code: '482917' })).rejects.toBeInstanceOf(
      AppError,
    );
  });

  it('400 + increments attempts on wrong code', async () => {
    users.put(buildUser());
    tokens.put(buildToken());

    await expect(useCase.execute({ userId: 'user_1', code: '000000' })).rejects.toMatchObject({
      code: 'VALIDATION_ERROR',
    });

    expect(tokens.all()[0]?.attempts).toBe(1);
    expect(tokens.all()[0]?.invalidated).toBe(false);
  });

  it('invalidates token after 5 wrong attempts', async () => {
    users.put(buildUser());
    tokens.put(buildToken());

    for (let i = 0; i < 5; i += 1) {
      await expect(useCase.execute({ userId: 'user_1', code: '000000' })).rejects.toBeInstanceOf(
        AppError,
      );
    }

    expect(tokens.all()[0]?.invalidated).toBe(true);
    const reasons = events.published
      .filter((e) => e.type === EMAIL_VERIFICATION_INVALIDATED)
      .map((e) => (e.payload as { reason: string }).reason);
    expect(reasons).toContain('too_many_attempts');
  });

  it('404 when user does not exist', async () => {
    await expect(useCase.execute({ userId: 'ghost', code: '482917' })).rejects.toMatchObject({
      code: 'NOT_FOUND',
    });
  });
});

import { beforeEach, describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { User } from '@/features/users/domain/entities/user.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { Credential as CredentialEntity } from '../../domain/entities/credential.js';
import { PasswordResetToken } from '../../domain/entities/password-reset-token.js';
import { PASSWORD_RESET } from '../../domain/events/password-reset.event.js';
import { PASSWORD_RESET_TOKEN_CONSUMED } from '../../domain/events/password-reset-token-consumed.event.js';
import { PASSWORD_RESET_TOKEN_INVALIDATED } from '../../domain/events/password-reset-token-invalidated.event.js';
import { REFRESH_TOKEN_REVOKED } from '../../domain/events/refresh-token-revoked.event.js';
import { HashedPassword } from '../../domain/value-objects/hashed-password.js';
import { ResetPasswordUseCase } from './reset-password.usecase.js';
import {
  FakeCredentialRepository,
  FakeEventPublisher,
  FakePasswordHasher,
  FakePasswordResetTokenRepository,
  FakeUnitOfWork,
  FakeUserRepository,
  FakeVerificationCodeHasher,
  FixedClock,
} from './fakes.js';

const buildUser = (verifiedAt: Date | null = new Date('2026-01-01T00:00:00Z')): User =>
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
  });

const buildCredential = (): CredentialEntity => {
  const c = CredentialEntity.issue({
    userId: 'user_1',
    passwordHash: HashedPassword.fromHash('argon2:original'),
    now: new Date('2026-01-01T00:00:00Z'),
  });
  c.pullEvents();
  return c;
};

const buildToken = (
  overrides: { codeHash?: string; expiresAt?: Date; invalidated?: boolean } = {},
): PasswordResetToken => {
  const issuedAt = new Date('2026-02-01T00:00:00Z');
  return PasswordResetToken.rehydrate({
    id: 'tok_pr_1',
    userId: 'user_1',
    codeHash: overrides.codeHash ?? 'h:482917',
    issuedAt,
    expiresAt: overrides.expiresAt ?? new Date('2026-02-03T00:00:00Z'),
    consumedAt: null,
    attempts: 0,
    invalidated: overrides.invalidated ?? false,
  });
};

describe('ResetPasswordUseCase', () => {
  let users: FakeUserRepository;
  let credentials: FakeCredentialRepository;
  let tokens: FakePasswordResetTokenRepository;
  let events: FakeEventPublisher;
  let passwordHasher: FakePasswordHasher;
  let codeHasher: FakeVerificationCodeHasher;
  let clock: FixedClock;
  let useCase: ResetPasswordUseCase;

  beforeEach(() => {
    users = new FakeUserRepository();
    credentials = new FakeCredentialRepository();
    tokens = new FakePasswordResetTokenRepository();
    events = new FakeEventPublisher();
    passwordHasher = new FakePasswordHasher();
    codeHasher = new FakeVerificationCodeHasher();
    clock = new FixedClock(new Date('2026-02-02T00:00:00Z'));
    useCase = new ResetPasswordUseCase(
      new FakeUnitOfWork(),
      users,
      credentials,
      tokens,
      passwordHasher,
      codeHasher,
      events,
      clock,
    );
  });

  it('changes password + consumes token + publishes events on the happy path', async () => {
    users.put(buildUser());
    credentials.put(buildCredential());
    tokens.put(buildToken());

    await useCase.execute({
      email: 'alice@example.com',
      code: '482917',
      newPassword: 'newPassw0rd!',
    });

    const persistedCred = await credentials.findByUserId('user_1');
    expect(persistedCred?.passwordHash.value).toBe('argon2:newPassw0rd!');
    expect(persistedCred?.passwordSetAt).toEqual(clock.now());

    const persistedToken = tokens.all()[0];
    expect(persistedToken?.isConsumed()).toBe(true);

    const types = events.published.map((e) => e.type);
    expect(types).toContain(PASSWORD_RESET_TOKEN_CONSUMED);
    expect(types).toContain(PASSWORD_RESET);
    // Refresh-token revocation is now handled by the
    // signOutAllOnPasswordReset consumer reacting to auth.passwordReset, not
    // by this use case. Verify no REFRESH_TOKEN_REVOKED events are emitted
    // synchronously here.
    expect(types).not.toContain(REFRESH_TOKEN_REVOKED);
  });

  it('rejects weak password before touching anything', async () => {
    users.put(buildUser());
    credentials.put(buildCredential());
    tokens.put(buildToken());

    await expect(
      useCase.execute({ email: 'alice@example.com', code: '482917', newPassword: 'short' }),
    ).rejects.toBeInstanceOf(AppError);

    const persistedCred = await credentials.findByUserId('user_1');
    expect(persistedCred?.passwordHash.value).toBe('argon2:original');
    expect(tokens.all()[0]?.isConsumed()).toBe(false);
  });

  it('returns generic error when email is unknown (no enumeration leak)', async () => {
    await expect(
      useCase.execute({
        email: 'ghost@example.com',
        code: '482917',
        newPassword: 'newPassw0rd!',
      }),
    ).rejects.toMatchObject({ message: expect.stringMatching(/invalid or expired/i) });
  });

  it('returns generic error when no open token exists', async () => {
    users.put(buildUser());
    credentials.put(buildCredential());

    await expect(
      useCase.execute({
        email: 'alice@example.com',
        code: '482917',
        newPassword: 'newPassw0rd!',
      }),
    ).rejects.toMatchObject({ message: expect.stringMatching(/invalid or expired/i) });
  });

  it('returns generic error + increments attempts when code mismatches', async () => {
    users.put(buildUser());
    credentials.put(buildCredential());
    tokens.put(buildToken());

    await expect(
      useCase.execute({
        email: 'alice@example.com',
        code: '000000',
        newPassword: 'newPassw0rd!',
      }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });

    expect(tokens.all()[0]?.attempts).toBe(1);
    expect(tokens.all()[0]?.invalidated).toBe(false);

    const persistedCred = await credentials.findByUserId('user_1');
    expect(persistedCred?.passwordHash.value).toBe('argon2:original');
  });

  it('invalidates the token after 5 wrong attempts', async () => {
    users.put(buildUser());
    credentials.put(buildCredential());
    tokens.put(buildToken());

    for (let i = 0; i < 5; i += 1) {
      await expect(
        useCase.execute({
          email: 'alice@example.com',
          code: '000000',
          newPassword: 'newPassw0rd!',
        }),
      ).rejects.toBeInstanceOf(AppError);
    }

    expect(tokens.all()[0]?.invalidated).toBe(true);
    const reasons = events.published
      .filter((e) => e.type === PASSWORD_RESET_TOKEN_INVALIDATED)
      .map((e) => (e.payload as { reason: string }).reason);
    expect(reasons).toContain('too_many_attempts');
  });

  it('rejects expired token with the same generic error', async () => {
    users.put(buildUser());
    credentials.put(buildCredential());
    tokens.put(buildToken({ expiresAt: new Date('2026-02-01T12:00:00Z') }));

    await expect(
      useCase.execute({
        email: 'alice@example.com',
        code: '482917',
        newPassword: 'newPassw0rd!',
      }),
    ).rejects.toMatchObject({ message: expect.stringMatching(/invalid or expired/i) });
  });
});

import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { PhoneVerifier, StartVerificationResult } from '@/core/sms/phone-verifier.port.js';
import { User } from '@/features/users/domain/entities/user.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { PhoneNumber } from '@/core/sms/phone-number.js';
import { PHONE_VERIFICATION_STARTED } from '../../../domain/events/phone-verification-started.event.js';
import { StartPhoneVerificationUseCase } from '../start-phone-verification.usecase.js';
import {
  FakeEventPublisher,
  FakeUnitOfWork,
  FakeUserRepository,
  FixedClock,
} from './fakes.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const FIXED_NOW = new Date('2026-05-01T10:00:00Z');
const VALID_PHONE = '+6591234567';

const buildUser = (overrides: {
  phone?: PhoneNumber | null;
  phoneVerifiedAt?: Date | null;
} = {}): User =>
  User.rehydrate({
    id: 'user_1',
    email: Email.create('alice@example.com'),
    displayName: DisplayName.create('Alice'),
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-01T00:00:00Z'),
    emailVerifiedAt: null,
    bio: null,
    avatarUrl: null,
    languages: [],
    interests: [],
    currentCity: null,
    travelerType: null,
    phone: overrides.phone ?? null,
    phoneVerifiedAt: overrides.phoneVerifiedAt ?? null,
  });

interface FakeVerifier extends PhoneVerifier {
  startVerificationMock: ReturnType<typeof vi.fn>;
}

const makeFakeVerifier = (result: StartVerificationResult): FakeVerifier => {
  const startVerificationMock = vi.fn().mockResolvedValue(result);
  return {
    startVerificationMock,
    startVerification: startVerificationMock,
    checkVerification: vi.fn(),
  };
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('StartPhoneVerificationUseCase', () => {
  let users: FakeUserRepository;
  let events: FakeEventPublisher;
  let clock: FixedClock;
  let unitOfWork: FakeUnitOfWork;

  beforeEach(() => {
    users = new FakeUserRepository();
    events = new FakeEventPublisher();
    clock = new FixedClock(FIXED_NOW);
    unitOfWork = new FakeUnitOfWork();
  });

  const makeUseCase = (verifier: PhoneVerifier) =>
    new StartPhoneVerificationUseCase({
      users,
      phoneVerifier: verifier,
      events,
      unitOfWork,
      clock,
    });

  // --- Happy path ---

  it("'sent' → publishes phoneVerificationStarted event with correct payload and returns { ok: true }", async () => {
    users.put(buildUser());
    const useCase = makeUseCase(makeFakeVerifier({ status: 'sent' }));

    const result = await useCase.execute({ userId: 'user_1', rawPhone: VALID_PHONE });

    expect(result).toEqual({ ok: true });
    expect(events.published).toHaveLength(1);
    const event = events.published[0];
    expect(event?.type).toBe(PHONE_VERIFICATION_STARTED);
    expect(event?.payload).toMatchObject({
      userId: 'user_1',
      phoneE164: VALID_PHONE,
      startedAt: FIXED_NOW.toISOString(),
    });
    expect(typeof event?.aggregateId).toBe('string');
    expect(event?.aggregateId.length).toBeGreaterThan(0);
  });

  // --- Verifier result branches ---

  it("'invalid' → throws AppError 400", async () => {
    users.put(buildUser());
    const useCase = makeUseCase(makeFakeVerifier({ status: 'invalid' }));

    await expect(
      useCase.execute({ userId: 'user_1', rawPhone: VALID_PHONE }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR', status: 400 });

    expect(events.published).toHaveLength(0);
  });

  it("'rate_limited' → throws AppError 422 with subcode 'sms_rate_limited'", async () => {
    users.put(buildUser());
    const useCase = makeUseCase(makeFakeVerifier({ status: 'rate_limited' }));

    await expect(
      useCase.execute({ userId: 'user_1', rawPhone: VALID_PHONE }),
    ).rejects.toMatchObject({
      code: 'UNPROCESSABLE',
      status: 422,
      details: { subcode: 'sms_rate_limited' },
    });

    expect(events.published).toHaveLength(0);
  });

  it("'provider_unavailable' → throws AppError 500", async () => {
    users.put(buildUser());
    const useCase = makeUseCase(makeFakeVerifier({ status: 'provider_unavailable' }));

    await expect(
      useCase.execute({ userId: 'user_1', rawPhone: VALID_PHONE }),
    ).rejects.toMatchObject({ code: 'INTERNAL', status: 500 });

    expect(events.published).toHaveLength(0);
  });

  // --- Idempotent re-start guard ---

  it('idempotent re-start: user already verified with same phone → returns { ok: true }, verifier NOT called', async () => {
    const phone = PhoneNumber.create(VALID_PHONE);
    users.put(buildUser({ phone, phoneVerifiedAt: new Date('2026-04-01T00:00:00Z') }));

    const verifier = makeFakeVerifier({ status: 'sent' });
    const useCase = makeUseCase(verifier);

    const result = await useCase.execute({ userId: 'user_1', rawPhone: VALID_PHONE });

    expect(result).toEqual({ ok: true });
    expect(verifier.startVerificationMock).not.toHaveBeenCalled();
    expect(events.published).toHaveLength(0);
  });

  it('re-start with a different phone while existing phone is verified → calls verifier', async () => {
    const existingPhone = PhoneNumber.create('+6591111111');
    users.put(buildUser({ phone: existingPhone, phoneVerifiedAt: new Date('2026-04-01T00:00:00Z') }));

    const verifier = makeFakeVerifier({ status: 'sent' });
    const useCase = makeUseCase(verifier);

    const result = await useCase.execute({ userId: 'user_1', rawPhone: VALID_PHONE });

    expect(result).toEqual({ ok: true });
    expect(verifier.startVerificationMock).toHaveBeenCalledOnce();
    expect(events.published).toHaveLength(1);
  });

  // --- User not found ---

  it('user not found → throws AppError 404', async () => {
    const useCase = makeUseCase(makeFakeVerifier({ status: 'sent' }));

    await expect(
      useCase.execute({ userId: 'ghost', rawPhone: VALID_PHONE }),
    ).rejects.toMatchObject({ code: 'NOT_FOUND', status: 404 });

    expect(events.published).toHaveLength(0);
  });

  // --- Bad E.164 input (pre-tx validation) ---

  it('bad E.164 input → throws AppError 400 BEFORE opening tx', async () => {
    // The UnitOfWork is replaced with a spy to verify it was never called.
    const runSpy = vi.fn();
    const spyUoW = { run: runSpy };
    const useCase = new StartPhoneVerificationUseCase({
      users,
      phoneVerifier: makeFakeVerifier({ status: 'sent' }),
      events,
      unitOfWork: spyUoW,
      clock,
    });

    await expect(
      useCase.execute({ userId: 'user_1', rawPhone: 'not-a-phone' }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR', status: 400 });

    expect(runSpy).not.toHaveBeenCalled();
    expect(events.published).toHaveLength(0);
  });
});

import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { CheckVerificationResult, PhoneVerifier } from '@/core/sms/phone-verifier.port.js';
import type { PhoneHasher } from '@/core/sms/phone-hasher.port.js';
import { PhoneNumber } from '@/core/sms/phone-number.js';
import { User } from '@/features/users/domain/entities/user.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { USER_PHONE_VERIFIED } from '../../../users/domain/events/user-phone-verified.event.js';
import { USER_PHONE_VERIFICATION_REVOKED } from '../../../users/domain/events/user-phone-verification-revoked.event.js';
import { USER_UPDATED } from '../../../users/domain/events/user-updated.event.js';
import { VerifyPhoneUseCase } from './verify-phone.usecase.js';
import { FakeEventPublisher, FakeUnitOfWork, FakeUserRepository, FixedClock } from './fakes.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const FIXED_NOW = new Date('2026-05-01T10:00:00Z');
const VALID_PHONE = '+6591234567';
const OTHER_PHONE = '+6598765432';
const VALID_CODE = '123456';

const FAKE_HASH = 'sha256:+6591234567';

const buildUser = (
  overrides: {
    id?: string;
    email?: string;
    phone?: PhoneNumber | null;
    phoneVerifiedAt?: Date | null;
  } = {},
): User =>
  User.rehydrate({
    id: overrides.id ?? 'user_1',
    email: Email.create(overrides.email ?? 'alice@example.com'),
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
    selfieStatus: null,
    selfieAttemptCount: 0,
    selfieLastFailureCategory: null,
    selfieAppealLockedAt: null,
    deletedAt: null,
    isAdmin: false,
  });

interface FakePhoneHasher extends PhoneHasher {
  hashMock: ReturnType<typeof vi.fn>;
}

const makeFakeHasher = (returnValue = FAKE_HASH): FakePhoneHasher => {
  const hashMock = vi.fn().mockReturnValue(returnValue);
  return { hashMock, hash: hashMock };
};

interface FakeVerifier extends PhoneVerifier {
  checkVerificationMock: ReturnType<typeof vi.fn>;
}

const makeFakeVerifier = (result: CheckVerificationResult): FakeVerifier => {
  const checkVerificationMock = vi.fn().mockResolvedValue(result);
  return {
    checkVerificationMock,
    startVerification: vi.fn(),
    checkVerification: checkVerificationMock,
  };
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('VerifyPhoneUseCase', () => {
  let users: FakeUserRepository;
  let events: FakeEventPublisher;
  let clock: FixedClock;
  let unitOfWork: FakeUnitOfWork;
  let phoneHasher: FakePhoneHasher;

  beforeEach(() => {
    users = new FakeUserRepository();
    events = new FakeEventPublisher();
    clock = new FixedClock(FIXED_NOW);
    unitOfWork = new FakeUnitOfWork();
    phoneHasher = makeFakeHasher();
  });

  const makeUseCase = (verifier: PhoneVerifier) =>
    new VerifyPhoneUseCase({
      users,
      phoneVerifier: verifier,
      phoneHasher,
      events,
      unitOfWork,
      clock,
    });

  // --- Happy path (no prior holder) ---

  it('happy path — no prior holder: B verified, events published in order [users.userUpdated, users.userPhoneVerified]', async () => {
    const userB = buildUser();
    users.put(userB);

    const verifier = makeFakeVerifier({ status: 'verified' });
    const result = await makeUseCase(verifier).execute({
      userId: 'user_1',
      rawPhone: VALID_PHONE,
      code: VALID_CODE,
    });

    // Returns updated user
    expect(result.user.id).toBe('user_1');
    expect(result.user.phoneVerifiedAt).not.toBeNull();
    expect(result.user.phone?.value).toBe(VALID_PHONE);

    // Exactly 2 events, correct types and order
    expect(events.published).toHaveLength(2);
    expect(events.published[0]?.type).toBe(USER_UPDATED);
    expect(events.published[1]?.type).toBe(USER_PHONE_VERIFIED);

    // phoneVerified payload
    expect(events.published[1]?.payload).toMatchObject({
      userId: 'user_1',
      phoneE164: VALID_PHONE,
      verifiedAt: FIXED_NOW.toISOString(),
    });

    // phoneHasher NOT called (no takeover)
    expect(phoneHasher.hashMock).not.toHaveBeenCalled();
  });

  // --- Contested takeover ---

  it('contested takeover: A revoked first (2 events), then B verified (2 events) — correct 4-event ordering', async () => {
    const phone = PhoneNumber.create(VALID_PHONE);

    // A is the existing verified holder
    const userA = buildUser({
      id: 'user_a',
      email: 'bob@example.com',
      phone,
      phoneVerifiedAt: new Date('2026-04-01T00:00:00Z'),
    });
    // B is the new verifier (different phone in DB, no verified phone)
    const userB = buildUser({
      id: 'user_b',
      email: 'alice@example.com',
      phone: null,
      phoneVerifiedAt: null,
    });
    users.put(userA);
    users.put(userB);

    const verifier = makeFakeVerifier({ status: 'verified' });
    const result = await makeUseCase(verifier).execute({
      userId: 'user_b',
      rawPhone: VALID_PHONE,
      code: VALID_CODE,
    });

    // B is returned with phone verified
    expect(result.user.id).toBe('user_b');
    expect(result.user.phoneVerifiedAt).not.toBeNull();

    // A's phoneVerifiedAt is now null (revoked), phone value retained
    const savedA = await users.findById('user_a');
    expect(savedA?.phoneVerifiedAt).toBeNull();
    expect(savedA?.phone?.value).toBe(VALID_PHONE); // phone retained for audit

    // B's phoneVerifiedAt is set
    const savedB = await users.findById('user_b');
    expect(savedB?.phoneVerifiedAt).not.toBeNull();

    // 4 events in correct causal order: A.userUpdated, A.userPhoneVerificationRevoked, B.userUpdated, B.userPhoneVerified
    expect(events.published).toHaveLength(4);
    expect(events.published[0]?.type).toBe(USER_UPDATED);
    expect(events.published[0]?.aggregateId).toBe('user_a');
    expect(events.published[1]?.type).toBe(USER_PHONE_VERIFICATION_REVOKED);
    expect(events.published[1]?.aggregateId).toBe('user_a');
    expect(events.published[2]?.type).toBe(USER_UPDATED);
    expect(events.published[2]?.aggregateId).toBe('user_b');
    expect(events.published[3]?.type).toBe(USER_PHONE_VERIFIED);
    expect(events.published[3]?.aggregateId).toBe('user_b');

    // phoneHasher called exactly once with phone.value
    expect(phoneHasher.hashMock).toHaveBeenCalledOnce();
    expect(phoneHasher.hashMock).toHaveBeenCalledWith(VALID_PHONE);

    // phoneE164Hash on revocation event matches hasher output
    expect(events.published[1]?.payload).toMatchObject({
      oldUserId: 'user_a',
      newUserId: 'user_b',
      phoneE164Hash: FAKE_HASH,
    });
  });

  // --- Verifier failure branches ---

  it("'invalid' → throws AppError 400 VALIDATION_ERROR", async () => {
    users.put(buildUser());
    const verifier = makeFakeVerifier({ status: 'invalid' });

    await expect(
      makeUseCase(verifier).execute({ userId: 'user_1', rawPhone: VALID_PHONE, code: 'wrong' }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR', status: 400 });

    expect(events.published).toHaveLength(0);
  });

  it("'expired' → throws AppError 400 VALIDATION_ERROR", async () => {
    users.put(buildUser());
    const verifier = makeFakeVerifier({ status: 'expired' });

    await expect(
      makeUseCase(verifier).execute({ userId: 'user_1', rawPhone: VALID_PHONE, code: VALID_CODE }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR', status: 400 });

    expect(events.published).toHaveLength(0);
  });

  it("'rate_limited' → throws AppError 422 UNPROCESSABLE with subcode 'sms_rate_limited'", async () => {
    users.put(buildUser());
    const verifier = makeFakeVerifier({ status: 'rate_limited' });

    await expect(
      makeUseCase(verifier).execute({ userId: 'user_1', rawPhone: VALID_PHONE, code: VALID_CODE }),
    ).rejects.toMatchObject({
      code: 'UNPROCESSABLE',
      status: 422,
      details: { subcode: 'sms_rate_limited' },
    });

    expect(events.published).toHaveLength(0);
  });

  it("'provider_unavailable' → throws AppError 500 INTERNAL", async () => {
    users.put(buildUser());
    const verifier = makeFakeVerifier({ status: 'provider_unavailable' });

    await expect(
      makeUseCase(verifier).execute({ userId: 'user_1', rawPhone: VALID_PHONE, code: VALID_CODE }),
    ).rejects.toMatchObject({ code: 'INTERNAL', status: 500 });

    expect(events.published).toHaveLength(0);
  });

  // --- Idempotent re-verify ---

  it('idempotent re-verify: B already has this phone verified → returns B WITHOUT calling verifier', async () => {
    const phone = PhoneNumber.create(VALID_PHONE);
    const userB = buildUser({ phone, phoneVerifiedAt: FIXED_NOW });
    users.put(userB);

    const verifier = makeFakeVerifier({ status: 'verified' });
    const result = await makeUseCase(verifier).execute({
      userId: 'user_1',
      rawPhone: VALID_PHONE,
      code: VALID_CODE,
    });

    expect(result.user.id).toBe('user_1');
    expect(verifier.checkVerificationMock).not.toHaveBeenCalled();
    expect(events.published).toHaveLength(0);
  });

  it('re-verify with different phone (not idempotent) → calls verifier', async () => {
    const existingPhone = PhoneNumber.create(OTHER_PHONE);
    const userB = buildUser({ phone: existingPhone, phoneVerifiedAt: FIXED_NOW });
    users.put(userB);

    const verifier = makeFakeVerifier({ status: 'verified' });
    await makeUseCase(verifier).execute({
      userId: 'user_1',
      rawPhone: VALID_PHONE,
      code: VALID_CODE,
    });

    expect(verifier.checkVerificationMock).toHaveBeenCalledOnce();
  });

  // --- User not found ---

  it('user not found → throws AppError 404 NOT_FOUND', async () => {
    const verifier = makeFakeVerifier({ status: 'verified' });

    await expect(
      makeUseCase(verifier).execute({ userId: 'ghost', rawPhone: VALID_PHONE, code: VALID_CODE }),
    ).rejects.toMatchObject({ code: 'NOT_FOUND', status: 404 });

    expect(events.published).toHaveLength(0);
  });

  // --- Bad E.164 input (pre-tx validation) ---

  it('bad E.164 input → throws AppError 400 BEFORE opening tx', async () => {
    const runSpy = vi.fn();
    const spyUoW = { run: runSpy };
    const useCase = new VerifyPhoneUseCase({
      users,
      phoneVerifier: makeFakeVerifier({ status: 'verified' }),
      phoneHasher,
      events,
      unitOfWork: spyUoW,
      clock,
    });

    await expect(
      useCase.execute({ userId: 'user_1', rawPhone: 'not-a-phone', code: VALID_CODE }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR', status: 400 });

    expect(runSpy).not.toHaveBeenCalled();
    expect(events.published).toHaveLength(0);
  });
});

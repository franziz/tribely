import { env } from '../config/env.js';
import { PrismaUnitOfWork } from '../db/prisma-unit-of-work.js';
import { prisma, type Db } from '../db/prisma.js';
import type { UnitOfWork } from '../db/unit-of-work.port.js';
import type { EmailSender } from '../email/email-sender.port.js';
import { LoggingEmailSender } from '../email/logging-email-sender.js';
import { ResendEmailSender } from '../email/resend-email-sender.js';
import type { PhoneHasher } from '../sms/phone-hasher.port.js';
import { Sha256PhoneHasher } from '../sms/sha256-phone-hasher.js';
import type { PhoneVerifier } from '../sms/phone-verifier.port.js';
import { LoggingPhoneVerifier } from '../sms/logging-phone-verifier.js';
import { TwilioPhoneVerifier } from '../sms/twilio-phone-verifier.js';
import type { FileStorage } from '../storage/file-storage.port.js';
import { LoggingFileStorage } from '../storage/logging-file-storage.js';
import { S3FileStorageAdapter } from '../storage/s3-file-storage.js';
import {
  ConsumerRegistry,
  OutboxDispatcher,
  OutboxEventPublisher,
  type EventPublisher,
} from '../events/index.js';
import type { Logger } from '../observability/logger.port.js';
import { PinoLogger } from '../observability/pino-logger.js';
import { InMemoryRateLimiter } from '../security/in-memory-rate-limiter.js';
import type { RateLimiter } from '../security/rate-limiter.port.js';

import { Argon2PasswordHasher } from '@/features/auth/infrastructure/adapters/argon2-password-hasher.js';
import { JwtAccessTokenIssuer } from '@/features/auth/infrastructure/adapters/jwt-access-token-issuer.js';
import { Sha256RefreshTokenHasher } from '@/features/auth/infrastructure/adapters/sha256-refresh-token-hasher.js';
import { Sha256VerificationCodeHasher } from '@/features/auth/infrastructure/adapters/sha256-verification-code-hasher.js';
import { SystemClock } from '@/features/auth/infrastructure/adapters/system-clock.js';
import { CredentialPrismaRepository } from '@/features/auth/infrastructure/persistence/credential.prisma-repository.js';
import { EmailVerificationTokenPrismaRepository } from '@/features/auth/infrastructure/persistence/email-verification-token.prisma-repository.js';
import { PasswordResetTokenPrismaRepository } from '@/features/auth/infrastructure/persistence/password-reset-token.prisma-repository.js';
import { RefreshTokenPrismaRepository } from '@/features/auth/infrastructure/persistence/refresh-token.prisma-repository.js';
import { IssueEmailVerificationUseCase } from '@/features/auth/application/usecases/issue-email-verification.usecase.js';
import { RefreshTokensUseCase } from '@/features/auth/application/usecases/refresh-tokens.usecase.js';
import { RequestPasswordResetUseCase } from '@/features/auth/application/usecases/request-password-reset.usecase.js';
import { ResendEmailVerificationUseCase } from '@/features/auth/application/usecases/resend-email-verification.usecase.js';
import { ResetPasswordUseCase } from '@/features/auth/application/usecases/reset-password.usecase.js';
import { SignInUseCase } from '@/features/auth/application/usecases/sign-in.usecase.js';
import { StartPhoneVerificationUseCase } from '@/features/auth/application/usecases/start-phone-verification.usecase.js';
import { VerifyPhoneUseCase } from '@/features/auth/application/usecases/verify-phone.usecase.js';
import { SignOutAllUseCase } from '@/features/auth/application/usecases/sign-out-all.usecase.js';
import { SignOutUseCase } from '@/features/auth/application/usecases/sign-out.usecase.js';
import { SignUpUseCase } from '@/features/auth/application/usecases/sign-up.usecase.js';
import { VerifyEmailUseCase } from '@/features/auth/application/usecases/verify-email.usecase.js';
import { registerAuthConsumers } from '@/features/auth/presentation/events/index.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { PasswordHasher } from '@/features/auth/domain/ports/password-hasher.port.js';
import type { RefreshTokenHasher } from '@/features/auth/domain/ports/refresh-token-hasher.port.js';
import type { VerificationCodeHasher } from '@/features/auth/domain/ports/verification-code-hasher.port.js';
import type { CredentialRepository } from '@/features/auth/domain/repositories/credential.repository.js';
import type { EmailVerificationTokenRepository } from '@/features/auth/domain/repositories/email-verification-token.repository.js';
import type { PasswordResetTokenRepository } from '@/features/auth/domain/repositories/password-reset-token.repository.js';
import type { RefreshTokenRepository } from '@/features/auth/domain/repositories/refresh-token.repository.js';

import { GetUserUseCase } from '@/features/users/application/usecases/get-user.usecase.js';
import { GetUserCapabilitiesUseCase } from '@/features/users/application/usecases/get-user-capabilities.usecase.js';
import { UpdateUserProfileUseCase } from '@/features/users/application/usecases/update-user-profile.usecase.js';
import { RejectSelfieUseCase } from '@/features/users/application/usecases/reject-selfie.usecase.js';
import { ApproveSelfieAppealUseCase } from '@/features/users/application/usecases/approve-selfie-appeal.usecase.js';
import { UserPrismaRepository } from '@/features/users/infrastructure/persistence/user.prisma-repository.js';
import { StubHostRatingsReadModel } from '@/features/users/infrastructure/adapters/stub-host-ratings-read-model.js';
import { registerUsersConsumers } from '@/features/users/presentation/events/index.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';

import { RecordEventDispatchUseCase } from '@/features/audit/application/usecases/record-event-dispatch.usecase.js';
import { RecordEventPublishedUseCase } from '@/features/audit/application/usecases/record-event-published.usecase.js';
import { RecordHttpCallUseCase } from '@/features/audit/application/usecases/record-http-call.usecase.js';
import { EventAuditLogPrismaRepository } from '@/features/audit/infrastructure/persistence/event-audit-log.prisma-repository.js';
import { HttpAuditLogPrismaRepository } from '@/features/audit/infrastructure/persistence/http-audit-log.prisma-repository.js';
import type { EventAuditLogRepository } from '@/features/audit/domain/repositories/event-audit-log.repository.js';
import type { HttpAuditLogRepository } from '@/features/audit/domain/repositories/http-audit-log.repository.js';

import { CancelEventUseCase } from '@/features/events/application/usecases/cancel-event.usecase.js';
import { CreateEventUseCase } from '@/features/events/application/usecases/create-event.usecase.js';
import { GetEventUseCase } from '@/features/events/application/usecases/get-event.usecase.js';
import { ListEventsUseCase } from '@/features/events/application/usecases/list-events.usecase.js';
import { UpdateEventUseCase } from '@/features/events/application/usecases/update-event.usecase.js';
import { EventPrismaRepository } from '@/features/events/infrastructure/persistence/event.prisma-repository.js';
import { registerEventsConsumers } from '@/features/events/presentation/events/index.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';

import { ApproveJoinRequestUseCase } from '@/features/join-requests/application/usecases/approve-join-request.usecase.js';
import { CancelJoinRequestByRequesterUseCase } from '@/features/join-requests/application/usecases/cancel-join-request-by-requester.usecase.js';
import { ListJoinRequestsByEventUseCase } from '@/features/join-requests/application/usecases/list-join-requests-by-event.usecase.js';
import { ListJoinRequestsByRequesterUseCase } from '@/features/join-requests/application/usecases/list-join-requests-by-requester.usecase.js';
import { RejectJoinRequestUseCase } from '@/features/join-requests/application/usecases/reject-join-request.usecase.js';
import { RequestToJoinEventUseCase } from '@/features/join-requests/application/usecases/request-to-join-event.usecase.js';
import { JoinRequestPrismaRepository } from '@/features/join-requests/infrastructure/persistence/join-request.prisma-repository.js';
import { registerJoinRequestsConsumers } from '@/features/join-requests/presentation/events/index.js';
import type { JoinRequestRepository } from '@/features/join-requests/domain/repositories/join-request.repository.js';

const buildEmailSender = (): EmailSender => {
  if (env.EMAIL_TRANSPORT === 'resend') {
    // Zod's superRefine on env guarantees RESEND_API_KEY is set here, but
    // an explicit check keeps the type narrowing local and avoids a
    // non-null assertion (banned by strictTypeChecked).
    if (!env.RESEND_API_KEY) {
      throw new Error('EMAIL_TRANSPORT=resend requires RESEND_API_KEY');
    }
    return new ResendEmailSender(env.RESEND_API_KEY, env.EMAIL_FROM);
  }
  return new LoggingEmailSender();
};

const buildPhoneVerifier = (): PhoneVerifier => {
  if (env.SMS_TRANSPORT === 'twilio') {
    // Zod's superRefine on env guarantees the three Twilio vars are set here,
    // but explicit checks keep type narrowing local and avoid non-null
    // assertions (banned by strictTypeChecked).
    if (!env.TWILIO_ACCOUNT_SID || !env.TWILIO_AUTH_TOKEN || !env.TWILIO_VERIFY_SERVICE_SID) {
      throw new Error(
        'SMS_TRANSPORT=twilio requires TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_VERIFY_SERVICE_SID',
      );
    }
    return new TwilioPhoneVerifier({
      accountSid: env.TWILIO_ACCOUNT_SID,
      authToken: env.TWILIO_AUTH_TOKEN,
      serviceSid: env.TWILIO_VERIFY_SERVICE_SID,
      allowedCountryCodes: env.SMS_ALLOWED_COUNTRY_CODES,
    });
  }
  return new LoggingPhoneVerifier();
};

const buildFileStorage = (): FileStorage => {
  if (env.STORAGE_TRANSPORT === 's3') {
    // Zod's superRefine on env guarantees these four vars are set when
    // STORAGE_TRANSPORT=s3, but explicit checks keep type narrowing local
    // and avoid non-null assertions (banned by strictTypeChecked).
    if (
      !env.STORAGE_BUCKET ||
      !env.STORAGE_REGION ||
      !env.STORAGE_ACCESS_KEY_ID ||
      !env.STORAGE_SECRET_ACCESS_KEY
    ) {
      throw new Error(
        'STORAGE_TRANSPORT=s3 requires STORAGE_BUCKET, STORAGE_REGION, STORAGE_ACCESS_KEY_ID, STORAGE_SECRET_ACCESS_KEY',
      );
    }
    // S3Client is constructed inside fromConfig() — keeping @aws-sdk/client-s3
    // imports isolated to s3-file-storage.ts (enforced by ESLint no-restricted-imports).
    return S3FileStorageAdapter.fromConfig({
      region: env.STORAGE_REGION,
      accessKeyId: env.STORAGE_ACCESS_KEY_ID,
      secretAccessKey: env.STORAGE_SECRET_ACCESS_KEY,
      bucket: env.STORAGE_BUCKET,
      readUrlMaxSeconds: env.STORAGE_READ_URL_MAX_SECONDS ?? 3600,
      uploadUrlMaxSeconds: env.STORAGE_UPLOAD_URL_MAX_SECONDS ?? 300,
      // exactOptionalPropertyTypes: spread undefined-guarded optionals so
      // the property is absent rather than present-with-undefined.
      ...(env.STORAGE_ENDPOINT ? { endpoint: env.STORAGE_ENDPOINT } : {}),
      ...(env.STORAGE_FORCE_PATH_STYLE ? { forcePathStyle: env.STORAGE_FORCE_PATH_STYLE } : {}),
    });
  }
  return new LoggingFileStorage();
};

const parseDurationSeconds = (value: string): number => {
  const match = /^(\d+)([smhd])$/.exec(value);
  if (!match) throw new Error(`Invalid TTL: ${value}`);
  const n = Number(match[1]);
  switch (match[2]) {
    case 's':
      return n;
    case 'm':
      return n * 60;
    case 'h':
      return n * 60 * 60;
    case 'd':
      return n * 60 * 60 * 24;
    default:
      throw new Error(`Invalid TTL unit: ${match[2] ?? 'unknown'}`);
  }
};

export interface Container {
  // Core
  db: Db;
  consumerRegistry: ConsumerRegistry;
  publisher: EventPublisher;
  unitOfWork: UnitOfWork;
  dispatcher: OutboxDispatcher;
  rateLimiter: RateLimiter;
  emailSender: EmailSender;
  phoneVerifier: PhoneVerifier;
  fileStorage: FileStorage;
  phoneHasher: PhoneHasher;
  logger: Logger;

  // Users
  userRepository: UserRepository;
  getUserUseCase: GetUserUseCase;
  updateUserProfileUseCase: UpdateUserProfileUseCase;
  getUserCapabilitiesUseCase: GetUserCapabilitiesUseCase;
  rejectSelfieUseCase: RejectSelfieUseCase;
  approveSelfieAppealUseCase: ApproveSelfieAppealUseCase;

  // Auth
  credentialRepository: CredentialRepository;
  refreshTokenRepository: RefreshTokenRepository;
  emailVerificationTokenRepository: EmailVerificationTokenRepository;
  passwordResetTokenRepository: PasswordResetTokenRepository;
  passwordHasher: PasswordHasher;
  accessTokens: AccessTokenIssuer;
  refreshHasher: RefreshTokenHasher;
  verificationCodeHasher: VerificationCodeHasher;
  clock: Clock;
  signUpUseCase: SignUpUseCase;
  signInUseCase: SignInUseCase;
  refreshTokensUseCase: RefreshTokensUseCase;
  signOutUseCase: SignOutUseCase;
  signOutAllUseCase: SignOutAllUseCase;
  issueEmailVerificationUseCase: IssueEmailVerificationUseCase;
  verifyEmailUseCase: VerifyEmailUseCase;
  resendEmailVerificationUseCase: ResendEmailVerificationUseCase;
  requestPasswordResetUseCase: RequestPasswordResetUseCase;
  resetPasswordUseCase: ResetPasswordUseCase;
  startPhoneVerificationUseCase: StartPhoneVerificationUseCase;
  verifyPhoneUseCase: VerifyPhoneUseCase;

  // Audit
  httpAuditLogRepository: HttpAuditLogRepository;
  eventAuditLogRepository: EventAuditLogRepository;
  recordHttpCallUseCase: RecordHttpCallUseCase;
  recordEventPublishedUseCase: RecordEventPublishedUseCase;
  recordEventDispatchUseCase: RecordEventDispatchUseCase;

  // Events
  eventRepository: EventRepository;
  createEventUseCase: CreateEventUseCase;
  listEventsUseCase: ListEventsUseCase;
  getEventUseCase: GetEventUseCase;
  updateEventUseCase: UpdateEventUseCase;
  cancelEventUseCase: CancelEventUseCase;

  // Join Requests
  joinRequestRepository: JoinRequestRepository;
  requestToJoinEventUseCase: RequestToJoinEventUseCase;
  approveJoinRequestUseCase: ApproveJoinRequestUseCase;
  rejectJoinRequestUseCase: RejectJoinRequestUseCase;
  cancelJoinRequestByRequesterUseCase: CancelJoinRequestByRequesterUseCase;
  listJoinRequestsByEventUseCase: ListJoinRequestsByEventUseCase;
  listJoinRequestsByRequesterUseCase: ListJoinRequestsByRequesterUseCase;
}

export const buildContainer = (): Container => {
  // --- Core ---
  const db = prisma;
  const consumerRegistry = new ConsumerRegistry();
  const publisher = new OutboxEventPublisher();
  const unitOfWork = new PrismaUnitOfWork(db);
  const dispatcher = new OutboxDispatcher(db, consumerRegistry);
  const rateLimiter = new InMemoryRateLimiter();
  const emailSender = buildEmailSender();
  const phoneVerifier = buildPhoneVerifier();
  const fileStorage = buildFileStorage();
  // Zod's superRefine on env guarantees PHONE_HASH_SALT is set when
  // NODE_ENV=production. In development/test it defaults to a fixed 32-char
  // sentinel so local dev works without manual env editing.
  const phoneHasher: PhoneHasher = new Sha256PhoneHasher(
    env.PHONE_HASH_SALT ?? 'dev-sentinel-phone-hash-salt-00000',
  );
  const logger: Logger = new PinoLogger();

  // --- Users ---
  const userRepository = new UserPrismaRepository(db);
  const getUserUseCase = new GetUserUseCase(userRepository, env.VERIFIED_SIGNAL_SET);
  const updateUserProfileUseCase = new UpdateUserProfileUseCase(
    unitOfWork,
    userRepository,
    publisher,
  );

  // --- Auth ---
  const credentialRepository = new CredentialPrismaRepository(db);
  const refreshTokenRepository = new RefreshTokenPrismaRepository(db);
  const emailVerificationTokenRepository = new EmailVerificationTokenPrismaRepository(db);
  const passwordResetTokenRepository = new PasswordResetTokenPrismaRepository(db);
  const passwordHasher = new Argon2PasswordHasher();
  const accessTokens = new JwtAccessTokenIssuer();
  const refreshHasher = new Sha256RefreshTokenHasher();
  const verificationCodeHasher = new Sha256VerificationCodeHasher();
  const clock = new SystemClock();
  const refreshTokenTtlSeconds = parseDurationSeconds(env.JWT_REFRESH_TTL);
  const emailVerificationTtlSeconds = parseDurationSeconds(env.EMAIL_VERIFICATION_TTL);
  const passwordResetTtlSeconds = parseDurationSeconds(env.PASSWORD_RESET_TTL);

  const signUpUseCase = new SignUpUseCase(
    unitOfWork,
    userRepository,
    credentialRepository,
    refreshTokenRepository,
    passwordHasher,
    accessTokens,
    refreshHasher,
    publisher,
    clock,
    refreshTokenTtlSeconds,
  );
  const signInUseCase = new SignInUseCase(
    unitOfWork,
    userRepository,
    credentialRepository,
    refreshTokenRepository,
    passwordHasher,
    accessTokens,
    refreshHasher,
    publisher,
    clock,
    refreshTokenTtlSeconds,
  );
  const refreshTokensUseCase = new RefreshTokensUseCase(
    unitOfWork,
    userRepository,
    refreshTokenRepository,
    accessTokens,
    refreshHasher,
    publisher,
    clock,
    refreshTokenTtlSeconds,
  );
  const signOutUseCase = new SignOutUseCase(
    unitOfWork,
    refreshTokenRepository,
    refreshHasher,
    publisher,
    clock,
  );
  const signOutAllUseCase = new SignOutAllUseCase(
    unitOfWork,
    refreshTokenRepository,
    publisher,
    clock,
  );
  const issueEmailVerificationUseCase = new IssueEmailVerificationUseCase(
    unitOfWork,
    userRepository,
    emailVerificationTokenRepository,
    verificationCodeHasher,
    publisher,
    emailSender,
    clock,
    emailVerificationTtlSeconds,
  );
  const verifyEmailUseCase = new VerifyEmailUseCase(
    unitOfWork,
    userRepository,
    emailVerificationTokenRepository,
    verificationCodeHasher,
    publisher,
    clock,
  );
  const resendEmailVerificationUseCase = new ResendEmailVerificationUseCase(
    userRepository,
    issueEmailVerificationUseCase,
  );
  const requestPasswordResetUseCase = new RequestPasswordResetUseCase(
    unitOfWork,
    userRepository,
    passwordResetTokenRepository,
    verificationCodeHasher,
    publisher,
    emailSender,
    clock,
    logger,
    passwordResetTtlSeconds,
  );
  const resetPasswordUseCase = new ResetPasswordUseCase(
    unitOfWork,
    userRepository,
    credentialRepository,
    passwordResetTokenRepository,
    passwordHasher,
    verificationCodeHasher,
    publisher,
    clock,
  );
  const startPhoneVerificationUseCase = new StartPhoneVerificationUseCase({
    users: userRepository,
    phoneVerifier,
    events: publisher,
    unitOfWork,
    clock,
  });
  const verifyPhoneUseCase = new VerifyPhoneUseCase({
    users: userRepository,
    phoneVerifier,
    phoneHasher,
    events: publisher,
    unitOfWork,
    clock,
  });

  // --- Users (selfie moderation — depends on clock from auth section) ---
  const rejectSelfieUseCase = new RejectSelfieUseCase(unitOfWork, userRepository, publisher, clock);
  const approveSelfieAppealUseCase = new ApproveSelfieAppealUseCase(
    unitOfWork,
    userRepository,
    publisher,
    clock,
  );

  // --- Audit ---
  const httpAuditLogRepository = new HttpAuditLogPrismaRepository(db);
  const eventAuditLogRepository = new EventAuditLogPrismaRepository(db);
  const recordHttpCallUseCase = new RecordHttpCallUseCase(httpAuditLogRepository);
  const recordEventPublishedUseCase = new RecordEventPublishedUseCase(eventAuditLogRepository);
  const recordEventDispatchUseCase = new RecordEventDispatchUseCase(eventAuditLogRepository);

  // Wire audit hooks into the events core. The publisher + dispatcher have
  // no compile-time dependency on the audit feature — the binding lives
  // here so the cross-cutting concern stays a wiring detail, not a layering
  // violation.
  publisher.setAuditHook({
    onPublished: (events, ctx) => recordEventPublishedUseCase.execute(events, ctx),
  });
  dispatcher.setOutcomeReporter({
    onOutcome: (input) => recordEventDispatchUseCase.execute(input),
  });

  // --- Events ---
  const eventRepository = new EventPrismaRepository(db);

  // User capabilities depend on eventRepository — wired here so createEvent / updateEvent
  // can receive it as a constructor dep without a forward-reference.
  const stubHostRatingsReadModel = new StubHostRatingsReadModel();
  const getUserCapabilitiesUseCase = new GetUserCapabilitiesUseCase(
    eventRepository,
    stubHostRatingsReadModel,
    userRepository,
  );

  const createEventUseCase = new CreateEventUseCase(
    unitOfWork,
    eventRepository,
    publisher,
    clock,
    getUserCapabilitiesUseCase,
  );
  const listEventsUseCase = new ListEventsUseCase(eventRepository, clock);
  const getEventUseCase = new GetEventUseCase(
    eventRepository,
    userRepository,
    env.VERIFIED_SIGNAL_SET,
  );
  const updateEventUseCase = new UpdateEventUseCase(
    unitOfWork,
    eventRepository,
    publisher,
    clock,
    getUserCapabilitiesUseCase,
  );
  const cancelEventUseCase = new CancelEventUseCase(unitOfWork, eventRepository, publisher, clock);

  // --- Join Requests ---
  const joinRequestRepository = new JoinRequestPrismaRepository(db);
  const requestToJoinEventUseCase = new RequestToJoinEventUseCase(
    unitOfWork,
    joinRequestRepository,
    eventRepository,
    publisher,
    clock,
  );
  const approveJoinRequestUseCase = new ApproveJoinRequestUseCase(
    unitOfWork,
    joinRequestRepository,
    eventRepository,
    publisher,
    clock,
  );
  const rejectJoinRequestUseCase = new RejectJoinRequestUseCase(
    unitOfWork,
    joinRequestRepository,
    eventRepository,
    publisher,
    clock,
  );
  const cancelJoinRequestByRequesterUseCase = new CancelJoinRequestByRequesterUseCase(
    unitOfWork,
    joinRequestRepository,
    publisher,
    clock,
  );
  const listJoinRequestsByEventUseCase = new ListJoinRequestsByEventUseCase(
    joinRequestRepository,
    eventRepository,
    userRepository,
  );
  const listJoinRequestsByRequesterUseCase = new ListJoinRequestsByRequesterUseCase(
    joinRequestRepository,
    eventRepository,
  );

  // --- Consumers (per-consumer offsets registry) ---
  registerUsersConsumers(consumerRegistry);
  registerAuthConsumers(consumerRegistry, {
    issueEmailVerification: issueEmailVerificationUseCase,
    signOutAll: signOutAllUseCase,
  });
  registerEventsConsumers(consumerRegistry);
  registerJoinRequestsConsumers(consumerRegistry);

  return {
    db,
    consumerRegistry,
    publisher,
    unitOfWork,
    dispatcher,
    rateLimiter,
    emailSender,
    phoneVerifier,
    fileStorage,
    phoneHasher,
    logger,
    userRepository,
    getUserUseCase,
    updateUserProfileUseCase,
    getUserCapabilitiesUseCase,
    rejectSelfieUseCase,
    approveSelfieAppealUseCase,
    credentialRepository,
    refreshTokenRepository,
    emailVerificationTokenRepository,
    passwordResetTokenRepository,
    passwordHasher,
    accessTokens,
    refreshHasher,
    verificationCodeHasher,
    clock,
    signUpUseCase,
    signInUseCase,
    refreshTokensUseCase,
    signOutUseCase,
    signOutAllUseCase,
    issueEmailVerificationUseCase,
    verifyEmailUseCase,
    resendEmailVerificationUseCase,
    requestPasswordResetUseCase,
    resetPasswordUseCase,
    startPhoneVerificationUseCase,
    verifyPhoneUseCase,
    httpAuditLogRepository,
    eventAuditLogRepository,
    recordHttpCallUseCase,
    recordEventPublishedUseCase,
    recordEventDispatchUseCase,
    eventRepository,
    createEventUseCase,
    listEventsUseCase,
    getEventUseCase,
    updateEventUseCase,
    cancelEventUseCase,
    joinRequestRepository,
    requestToJoinEventUseCase,
    approveJoinRequestUseCase,
    rejectJoinRequestUseCase,
    cancelJoinRequestByRequesterUseCase,
    listJoinRequestsByEventUseCase,
    listJoinRequestsByRequesterUseCase,
  };
};

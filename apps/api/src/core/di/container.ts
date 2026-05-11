import { env } from '../config/env.js';
import { PrismaUnitOfWork } from '../db/prisma-unit-of-work.js';
import { prisma, type Db } from '../db/prisma.js';
import type { UnitOfWork } from '../db/unit-of-work.port.js';
import type { EmailSender } from '../email/email-sender.port.js';
import { LoggingEmailSender } from '../email/logging-email-sender.js';
import { ResendEmailSender } from '../email/resend-email-sender.js';
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
import { UserPrismaRepository } from '@/features/users/infrastructure/persistence/user.prisma-repository.js';
import { registerUsersConsumers } from '@/features/users/presentation/events/index.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';

import { RecordEventDispatchUseCase } from '@/features/audit/application/usecases/record-event-dispatch.usecase.js';
import { RecordEventPublishedUseCase } from '@/features/audit/application/usecases/record-event-published.usecase.js';
import { RecordHttpCallUseCase } from '@/features/audit/application/usecases/record-http-call.usecase.js';
import { EventAuditLogPrismaRepository } from '@/features/audit/infrastructure/persistence/event-audit-log.prisma-repository.js';
import { HttpAuditLogPrismaRepository } from '@/features/audit/infrastructure/persistence/http-audit-log.prisma-repository.js';
import type { EventAuditLogRepository } from '@/features/audit/domain/repositories/event-audit-log.repository.js';
import type { HttpAuditLogRepository } from '@/features/audit/domain/repositories/http-audit-log.repository.js';

import { EventPrismaRepository } from '@/features/events/infrastructure/persistence/event.prisma-repository.js';
import { registerEventsConsumers } from '@/features/events/presentation/events/index.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';

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
  logger: Logger;

  // Users
  userRepository: UserRepository;
  getUserUseCase: GetUserUseCase;

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

  // Audit
  httpAuditLogRepository: HttpAuditLogRepository;
  eventAuditLogRepository: EventAuditLogRepository;
  recordHttpCallUseCase: RecordHttpCallUseCase;
  recordEventPublishedUseCase: RecordEventPublishedUseCase;
  recordEventDispatchUseCase: RecordEventDispatchUseCase;

  // Events
  eventRepository: EventRepository;
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
  const logger: Logger = new PinoLogger();

  // --- Users ---
  const userRepository = new UserPrismaRepository(db);
  const getUserUseCase = new GetUserUseCase(userRepository);

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

  // --- Consumers (per-consumer offsets registry) ---
  registerUsersConsumers(consumerRegistry);
  registerAuthConsumers(consumerRegistry, {
    issueEmailVerification: issueEmailVerificationUseCase,
    signOutAll: signOutAllUseCase,
  });
  registerEventsConsumers(consumerRegistry);

  return {
    db,
    consumerRegistry,
    publisher,
    unitOfWork,
    dispatcher,
    rateLimiter,
    emailSender,
    logger,
    userRepository,
    getUserUseCase,
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
    httpAuditLogRepository,
    eventAuditLogRepository,
    recordHttpCallUseCase,
    recordEventPublishedUseCase,
    recordEventDispatchUseCase,
    eventRepository,
  };
};

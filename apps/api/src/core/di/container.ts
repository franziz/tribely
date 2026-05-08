import { PrismaUnitOfWork } from '../db/prisma-unit-of-work.js';
import { prisma, type Db } from '../db/prisma.js';
import type { UnitOfWork } from '../db/unit-of-work.port.js';
import {
  InProcessEventBus,
  OutboxDispatcher,
  OutboxEventPublisher,
  type EventBus,
  type EventPublisher,
} from '../events/index.js';

import { Argon2PasswordHasher } from '@/features/auth/infrastructure/adapters/argon2-password-hasher.js';
import { JwtTokenIssuer } from '@/features/auth/infrastructure/adapters/jwt-token-issuer.js';
import { SystemClock } from '@/features/auth/infrastructure/adapters/system-clock.js';
import { CredentialPrismaRepository } from '@/features/auth/infrastructure/persistence/credential.prisma-repository.js';
import { SignInUseCase } from '@/features/auth/application/usecases/sign-in.usecase.js';
import { SignUpUseCase } from '@/features/auth/application/usecases/sign-up.usecase.js';
import { registerAuthSubscribers } from '@/features/auth/presentation/events/index.js';
import type { CredentialRepository } from '@/features/auth/domain/repositories/credential.repository.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { PasswordHasher } from '@/features/auth/domain/ports/password-hasher.port.js';
import type { TokenIssuer } from '@/features/auth/domain/ports/token-issuer.port.js';

import { UserPrismaRepository } from '@/features/users/infrastructure/persistence/user.prisma-repository.js';
import { GetUserUseCase } from '@/features/users/application/usecases/get-user.usecase.js';
import { registerUsersSubscribers } from '@/features/users/presentation/events/index.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';

export interface Container {
  // Core
  db: Db;
  bus: EventBus;
  publisher: EventPublisher;
  unitOfWork: UnitOfWork;
  dispatcher: OutboxDispatcher;

  // Users
  userRepository: UserRepository;
  getUserUseCase: GetUserUseCase;

  // Auth
  credentialRepository: CredentialRepository;
  passwordHasher: PasswordHasher;
  tokenIssuer: TokenIssuer;
  clock: Clock;
  signUpUseCase: SignUpUseCase;
  signInUseCase: SignInUseCase;
}

export const buildContainer = (): Container => {
  // --- Core ---
  const db = prisma;
  const bus = new InProcessEventBus();
  const publisher = new OutboxEventPublisher();
  const unitOfWork = new PrismaUnitOfWork(db);
  const dispatcher = new OutboxDispatcher(db, bus);

  // --- Users ---
  const userRepository = new UserPrismaRepository(db);
  const getUserUseCase = new GetUserUseCase(userRepository);

  // --- Auth ---
  const credentialRepository = new CredentialPrismaRepository(db);
  const passwordHasher = new Argon2PasswordHasher();
  const tokenIssuer = new JwtTokenIssuer();
  const clock = new SystemClock();

  const signUpUseCase = new SignUpUseCase(
    unitOfWork,
    userRepository,
    credentialRepository,
    passwordHasher,
    tokenIssuer,
    publisher,
    clock,
  );
  const signInUseCase = new SignInUseCase(
    unitOfWork,
    userRepository,
    credentialRepository,
    passwordHasher,
    tokenIssuer,
    publisher,
    clock,
  );

  // --- Subscribers ---
  registerUsersSubscribers(bus);
  registerAuthSubscribers(bus);

  return {
    db,
    bus,
    publisher,
    unitOfWork,
    dispatcher,
    userRepository,
    getUserUseCase,
    credentialRepository,
    passwordHasher,
    tokenIssuer,
    clock,
    signUpUseCase,
    signInUseCase,
  };
};

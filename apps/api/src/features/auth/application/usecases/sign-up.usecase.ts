import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { User } from '@/features/users/domain/entities/user.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { Credential } from '../../domain/entities/credential.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { PasswordHasher } from '../../domain/ports/password-hasher.port.js';
import type { TokenIssuer, AuthTokens } from '../../domain/ports/token-issuer.port.js';
import type { CredentialRepository } from '../../domain/repositories/credential.repository.js';
import { Password } from '../../domain/value-objects/password.js';

export interface SignUpInput {
  email: string;
  password: string;
  displayName: string;
}

export interface SignUpResult {
  user: User;
  tokens: AuthTokens;
}

/**
 * Cross-context use case: registers a new User (users) AND issues their
 * Credential (auth) atomically. Lives in `auth` because the externally
 * observable action is "sign up with credentials" — auth owns the route.
 *
 * The atomicity is provided by UnitOfWork: both repositories and the
 * event publisher receive the same TxContext, so the User row, the
 * Credential row, and both domain events commit together (or not at all).
 */
export class SignUpUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly credentials: CredentialRepository,
    private readonly hasher: PasswordHasher,
    private readonly tokens: TokenIssuer,
    private readonly events: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: SignUpInput): Promise<SignUpResult> {
    const email = Email.create(input.email);
    const displayName = DisplayName.create(input.displayName);
    const password = Password.create(input.password);

    const existing = await this.users.findByEmail(email);
    if (existing) throw AppError.conflict('Email already registered');

    const passwordHash = await this.hasher.hash(password);
    const now = this.clock.now();

    const user = User.register({ id: createId(), email, displayName, now });
    const credential = Credential.issue({
      userId: user.id,
      passwordHash,
      now,
    });

    await this.unitOfWork.run(async (ctx) => {
      await this.users.save(user, ctx);
      await this.credentials.save(credential, ctx);
      await this.events.publish(ctx, ...user.pullEvents(), ...credential.pullEvents());
    });

    const issued = await this.tokens.issue({ userId: user.id, email: email.value });

    return { user, tokens: issued };
  }
}

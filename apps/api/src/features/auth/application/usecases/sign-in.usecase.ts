import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { User } from '@/features/users/domain/entities/user.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { PasswordHasher } from '../../domain/ports/password-hasher.port.js';
import type { TokenIssuer, AuthTokens } from '../../domain/ports/token-issuer.port.js';
import type { CredentialRepository } from '../../domain/repositories/credential.repository.js';
import { Password } from '../../domain/value-objects/password.js';

export interface SignInInput {
  email: string;
  password: string;
}

export interface SignInResult {
  user: User;
  tokens: AuthTokens;
}

export class SignInUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly credentials: CredentialRepository,
    private readonly hasher: PasswordHasher,
    private readonly tokens: TokenIssuer,
    private readonly events: EventPublisher,
    private readonly clock: Clock,
  ) {}

  async execute(input: SignInInput): Promise<SignInResult> {
    const email = Email.create(input.email);
    const password = Password.create(input.password);

    const user = await this.users.findByEmail(email);
    if (!user) throw AppError.unauthorized('Invalid credentials');

    const credential = await this.credentials.findByUserId(user.id);
    if (!credential) throw AppError.unauthorized('Invalid credentials');

    const valid = await this.hasher.verify(password, credential.passwordHash);
    if (!valid) throw AppError.unauthorized('Invalid credentials');

    credential.markSignedIn(this.clock.now());

    await this.unitOfWork.run(async (ctx) => {
      await this.credentials.save(credential, ctx);
      await this.events.publish(ctx, ...credential.pullEvents());
    });

    const issued = await this.tokens.issue({ userId: user.id, email: email.value });
    return { user, tokens: issued };
  }
}

import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { User } from '@/features/users/domain/entities/user.js';
import { DisplayName } from '@/features/users/domain/value-objects/display-name.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { Credential } from '../../domain/entities/credential.js';
import { RefreshToken } from '../../domain/entities/refresh-token.js';
import type { AccessTokenIssuer } from '../../domain/ports/access-token-issuer.port.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { PasswordHasher } from '../../domain/ports/password-hasher.port.js';
import type { RefreshTokenHasher } from '../../domain/ports/refresh-token-hasher.port.js';
import type { CredentialRepository } from '../../domain/repositories/credential.repository.js';
import type { RefreshTokenRepository } from '../../domain/repositories/refresh-token.repository.js';
import { Password } from '../../domain/value-objects/password.js';
import type { IssuedAuthSession } from '../dto/auth-result.js';

export interface SignUpInput {
  email: string;
  password: string;
  displayName: string;
  deviceLabel?: string | null;
}

export class SignUpUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly credentials: CredentialRepository,
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly hasher: PasswordHasher,
    private readonly accessTokens: AccessTokenIssuer,
    private readonly refreshHasher: RefreshTokenHasher,
    private readonly events: EventPublisher,
    private readonly clock: Clock,
    private readonly refreshTokenTtlSeconds: number,
  ) {}

  async execute(input: SignUpInput): Promise<IssuedAuthSession> {
    const email = Email.create(input.email);
    const displayName = DisplayName.create(input.displayName);
    const password = Password.create(input.password);

    const existing = await this.users.findByEmail(email);
    if (existing) throw AppError.conflict('Email already registered');

    const passwordHash = await this.hasher.hash(password);
    const now = this.clock.now();
    const refreshExpiresAt = new Date(now.getTime() + this.refreshTokenTtlSeconds * 1000);

    const user = User.register({ id: createId(), email, displayName, now });
    const credential = Credential.issue({ userId: user.id, passwordHash, now });
    const refresh = this.refreshHasher.generate();
    const refreshToken = RefreshToken.issue({
      id: createId(),
      userId: user.id,
      tokenHash: refresh.hash,
      expiresAt: refreshExpiresAt,
      deviceLabel: input.deviceLabel ?? null,
      now,
    });

    await this.unitOfWork.run(async (ctx) => {
      await this.users.save(user, ctx);
      await this.credentials.save(credential, ctx);
      await this.refreshTokens.save(refreshToken, ctx);
      await this.events.publish(
        ctx,
        ...user.pullEvents(),
        ...credential.pullEvents(),
        ...refreshToken.pullEvents(),
      );
    });

    const accessToken = await this.accessTokens.issue({ userId: user.id, email: email.value });

    return {
      user,
      accessToken,
      refreshTokenPlaintext: refresh.plaintext,
      refreshTokenExpiresAt: refreshExpiresAt,
    };
  }
}

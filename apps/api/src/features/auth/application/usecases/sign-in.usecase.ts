import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { Email } from '@/features/users/domain/value-objects/email.js';
import { RefreshToken } from '../../domain/entities/refresh-token.js';
import type { AccessTokenIssuer } from '../../domain/ports/access-token-issuer.port.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { PasswordHasher } from '../../domain/ports/password-hasher.port.js';
import type { RefreshTokenHasher } from '../../domain/ports/refresh-token-hasher.port.js';
import type { CredentialRepository } from '../../domain/repositories/credential.repository.js';
import type { RefreshTokenRepository } from '../../domain/repositories/refresh-token.repository.js';
import { Password } from '../../domain/value-objects/password.js';
import type { IssuedAuthSession } from '../dto/auth-result.js';

export interface SignInInput {
  email: string;
  password: string;
  deviceLabel?: string | null;
}

export class SignInUseCase {
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

  async execute(input: SignInInput): Promise<IssuedAuthSession> {
    const email = Email.create(input.email);
    const password = Password.create(input.password);

    const user = await this.users.findByEmail(email);
    if (!user) throw AppError.unauthorized('Invalid credentials');

    const credential = await this.credentials.findByUserId(user.id);
    if (!credential) throw AppError.unauthorized('Invalid credentials');

    const valid = await this.hasher.verify(password, credential.passwordHash);
    if (!valid) throw AppError.unauthorized('Invalid credentials');

    const now = this.clock.now();
    const refreshExpiresAt = new Date(now.getTime() + this.refreshTokenTtlSeconds * 1000);

    credential.markSignedIn(now);
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
      await this.credentials.save(credential, ctx);
      await this.refreshTokens.save(refreshToken, ctx);
      await this.events.publish(
        ctx,
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

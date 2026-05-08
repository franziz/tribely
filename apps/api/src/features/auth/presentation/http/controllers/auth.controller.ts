import type { Context } from 'hono';
import type { User } from '@/features/users/domain/entities/user.js';
import type { SignInUseCase } from '../../../application/usecases/sign-in.usecase.js';
import type { SignUpUseCase } from '../../../application/usecases/sign-up.usecase.js';
import type { AuthTokens } from '../../../domain/ports/token-issuer.port.js';
import type { AuthResponse, SignInBody, SignUpBody } from '../schemas/auth.schemas.js';

const toResponse = (user: User, tokens: AuthTokens): AuthResponse => ({
  user: {
    id: user.id,
    email: user.email.value,
    displayName: user.displayName.value,
    createdAt: user.createdAt.toISOString(),
    updatedAt: user.updatedAt.toISOString(),
  },
  tokens: {
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    accessTokenExpiresAt: tokens.accessTokenExpiresAt.toISOString(),
  },
});

export class AuthController {
  constructor(
    private readonly signUp: SignUpUseCase,
    private readonly signIn: SignInUseCase,
  ) {}

  signUpAction = async (c: Context, body: SignUpBody) => {
    const result = await this.signUp.execute(body);
    return c.json(toResponse(result.user, result.tokens), 201);
  };

  signInAction = async (c: Context, body: SignInBody) => {
    const result = await this.signIn.execute(body);
    return c.json(toResponse(result.user, result.tokens), 200);
  };
}

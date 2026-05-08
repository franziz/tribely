import type { Context } from 'hono';
import type { Container } from '@/core/di/container.js';
import type { User } from '../../domain/entities/user.js';
import type { AuthTokens } from '../../domain/services/token.service.js';
import type { AuthResponse, SignInBody, SignUpBody } from '../schemas/auth.schemas.js';

const toAuthResponse = (user: User, tokens: AuthTokens): AuthResponse => ({
  user: {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
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
  constructor(private readonly container: Container) {}

  signUp = async (c: Context, body: SignUpBody) => {
    const result = await this.container.signUpUseCase.execute(body);
    return c.json(toAuthResponse(result.user, result.tokens), 201);
  };

  signIn = async (c: Context, body: SignInBody) => {
    const result = await this.container.signInUseCase.execute(body);
    return c.json(toAuthResponse(result.user, result.tokens), 200);
  };
}

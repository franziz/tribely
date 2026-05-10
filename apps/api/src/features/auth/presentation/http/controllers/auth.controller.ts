import type { Context } from 'hono';
import type { GetUserUseCase } from '@/features/users/application/usecases/get-user.usecase.js';
import type { User } from '@/features/users/domain/entities/user.js';
import type { UserResponse } from '@/features/users/presentation/http/schemas/user.schemas.js';
import type { RefreshTokensUseCase } from '../../../application/usecases/refresh-tokens.usecase.js';
import type { ResendEmailVerificationUseCase } from '../../../application/usecases/resend-email-verification.usecase.js';
import type { SignInUseCase } from '../../../application/usecases/sign-in.usecase.js';
import type { SignOutAllUseCase } from '../../../application/usecases/sign-out-all.usecase.js';
import type { SignOutUseCase } from '../../../application/usecases/sign-out.usecase.js';
import type { SignUpUseCase } from '../../../application/usecases/sign-up.usecase.js';
import type { VerifyEmailUseCase } from '../../../application/usecases/verify-email.usecase.js';
import type { IssuedAuthSession } from '../../../application/dto/auth-result.js';
import type {
  AuthResponse,
  RefreshBody,
  SignInBody,
  SignOutAllResponse,
  SignOutBody,
  SignUpBody,
  VerifyEmailBody,
} from '../schemas/auth.schemas.js';

const toUserResponse = (user: User): UserResponse => ({
  id: user.id,
  email: user.email.value,
  displayName: user.displayName.value,
  emailVerifiedAt: user.emailVerifiedAt?.toISOString() ?? null,
  createdAt: user.createdAt.toISOString(),
  updatedAt: user.updatedAt.toISOString(),
});

const toAuthResponse = (session: IssuedAuthSession): AuthResponse => ({
  user: toUserResponse(session.user),
  accessToken: {
    value: session.accessToken.value,
    expiresAt: session.accessToken.expiresAt.toISOString(),
  },
  refreshToken: {
    value: session.refreshTokenPlaintext,
    expiresAt: session.refreshTokenExpiresAt.toISOString(),
  },
});

export class AuthController {
  constructor(
    private readonly signUp: SignUpUseCase,
    private readonly signIn: SignInUseCase,
    private readonly refreshTokens: RefreshTokensUseCase,
    private readonly signOutOne: SignOutUseCase,
    private readonly signOutAll: SignOutAllUseCase,
    private readonly getUser: GetUserUseCase,
    private readonly verifyEmail: VerifyEmailUseCase,
    private readonly resendVerification: ResendEmailVerificationUseCase,
  ) {}

  signUpAction = async (c: Context, body: SignUpBody) => {
    const result = await this.signUp.execute({
      ...body,
      deviceLabel: body.deviceLabel ?? null,
    });
    return c.json(toAuthResponse(result), 201);
  };

  signInAction = async (c: Context, body: SignInBody) => {
    const result = await this.signIn.execute({
      ...body,
      deviceLabel: body.deviceLabel ?? null,
    });
    return c.json(toAuthResponse(result), 200);
  };

  refreshAction = async (c: Context, body: RefreshBody) => {
    const result = await this.refreshTokens.execute({
      refreshTokenPlaintext: body.refreshToken,
      deviceLabel: body.deviceLabel ?? null,
    });
    return c.json(toAuthResponse(result), 200);
  };

  signOutAction = async (c: Context, body: SignOutBody) => {
    await this.signOutOne.execute({ refreshTokenPlaintext: body.refreshToken });
    return c.body(null, 204);
  };

  signOutAllAction = async (c: Context, userId: string) => {
    const result = await this.signOutAll.execute({ userId });
    return c.json<SignOutAllResponse>({ revokedCount: result.revokedCount }, 200);
  };

  meAction = async (c: Context, userId: string) => {
    const user = await this.getUser.execute({ id: userId });
    return c.json(toUserResponse(user), 200);
  };

  verifyEmailAction = async (c: Context, userId: string, body: VerifyEmailBody) => {
    const result = await this.verifyEmail.execute({ userId, code: body.code });
    return c.json(toUserResponse(result.user), 200);
  };

  resendVerificationAction = async (c: Context, userId: string) => {
    await this.resendVerification.execute({ userId });
    return c.body(null, 204);
  };
}

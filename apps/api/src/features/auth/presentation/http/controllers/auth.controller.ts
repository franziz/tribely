import type { Context } from 'hono';
import type { GetUserUseCase } from '@/features/users/application/usecases/get-user.usecase.js';
import type { User } from '@/features/users/domain/entities/user.js';
import type { RefreshTokensUseCase } from '../../../application/usecases/refresh-tokens.usecase.js';
import type { RequestPasswordResetUseCase } from '../../../application/usecases/request-password-reset.usecase.js';
import type { ResendEmailVerificationUseCase } from '../../../application/usecases/resend-email-verification.usecase.js';
import type { ResetPasswordUseCase } from '../../../application/usecases/reset-password.usecase.js';
import type { SignInUseCase } from '../../../application/usecases/sign-in.usecase.js';
import type { SignOutAllUseCase } from '../../../application/usecases/sign-out-all.usecase.js';
import type { SignOutUseCase } from '../../../application/usecases/sign-out.usecase.js';
import type { SignUpUseCase } from '../../../application/usecases/sign-up.usecase.js';
import type { VerifyEmailUseCase } from '../../../application/usecases/verify-email.usecase.js';
import type { IssuedAuthSession } from '../../../application/dto/auth-result.js';
import type {
  AuthResponse,
  AuthUserDto,
  ForgotPasswordBody,
  RefreshBody,
  ResetPasswordBody,
  SignInBody,
  SignOutAllResponse,
  SignOutBody,
  SignUpBody,
  VerifyEmailBody,
} from '../schemas/auth.schemas.js';

const toAuthUserDto = (user: User): AuthUserDto => ({
  id: user.id,
  email: user.email.value,
  displayName: user.displayName.value,
  emailVerifiedAt: user.emailVerifiedAt?.toISOString() ?? null,
  bio: user.bio?.value ?? null,
  avatarUrl: user.avatarUrl?.value ?? null,
  languages: user.languages.map((l) => l.value),
  interests: user.interests.map((i) => i.value),
  currentCity: user.currentCity?.value ?? null,
  travelerType: user.travelerType?.value ?? null,
  createdAt: user.createdAt.toISOString(),
  updatedAt: user.updatedAt.toISOString(),
});

const toAuthResponse = (session: IssuedAuthSession): AuthResponse => ({
  user: toAuthUserDto(session.user),
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
    private readonly requestPasswordReset: RequestPasswordResetUseCase,
    private readonly resetPassword: ResetPasswordUseCase,
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
    return c.json(toAuthUserDto(user), 200);
  };

  verifyEmailAction = async (c: Context, userId: string, body: VerifyEmailBody) => {
    const result = await this.verifyEmail.execute({ userId, code: body.code });
    return c.json(toAuthUserDto(result.user), 200);
  };

  resendVerificationAction = async (c: Context, userId: string) => {
    await this.resendVerification.execute({ userId });
    return c.body(null, 204);
  };

  // Always returns 200 with the same neutral message — never reveals whether
  // the email is on file (enumeration safety). The use case silently no-ops
  // for unknown / unverified accounts and info-logs for ops.
  forgotPasswordAction = async (c: Context, body: ForgotPasswordBody) => {
    await this.requestPasswordReset.execute({ email: body.email });
    return c.json(
      { ok: true, message: "If your email is on file, you'll get a reset code shortly." },
      200,
    );
  };

  resetPasswordAction = async (c: Context, body: ResetPasswordBody) => {
    await this.resetPassword.execute({
      email: body.email,
      code: body.code,
      newPassword: body.newPassword,
    });
    return c.body(null, 204);
  };
}

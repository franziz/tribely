import type { Context } from 'hono';
import type { User } from '../../../domain/entities/user.js';
import type { GetUserUseCase } from '../../../application/usecases/get-user.usecase.js';
import type { GetUserCapabilitiesUseCase } from '../../../application/usecases/get-user-capabilities.usecase.js';
import type { UpdateUserProfileInput } from '../../../application/usecases/update-user-profile.usecase.js';
import type { UpdateUserProfileUseCase } from '../../../application/usecases/update-user-profile.usecase.js';
import type { DeleteAccountUseCase } from '../../../application/usecases/delete-account.usecase.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { AuthVariables } from '@/core/middleware/require-auth.js';
import type { UpdateUserProfileBody, UserResponse } from '../schemas/user.schemas.js';

const toResponse = (user: User, isVerified: boolean): UserResponse => ({
  id: user.id,
  email: user.email.value,
  displayName: user.displayName.value,
  emailVerifiedAt: user.emailVerifiedAt?.toISOString() ?? null,
  isVerified,
  bio: user.bio?.value ?? null,
  avatarUrl: user.avatarUrl?.value ?? null,
  languages: user.languages.map((l) => l.value),
  interests: user.interests.map((i) => i.value),
  currentCity: user.currentCity?.value ?? null,
  travelerType: user.travelerType?.value ?? null,
  createdAt: user.createdAt.toISOString(),
  updatedAt: user.updatedAt.toISOString(),
});

/**
 * Build a use-case input object with patch semantics: only keys present in
 * the request body are forwarded. Under exactOptionalPropertyTypes, spreading
 * the Zod-parsed body would inject `undefined` for absent optional keys, which
 * the use case interface doesn't accept. Building explicitly preserves the
 * "absent key = don't touch" contract.
 */
const buildUpdateInput = (
  userId: string,
  body: UpdateUserProfileBody,
  now: Date,
): UpdateUserProfileInput => {
  const input: UpdateUserProfileInput = { userId, now };

  if ('bio' in body) input.bio = body.bio ?? null;
  if ('avatarUrl' in body) input.avatarUrl = body.avatarUrl ?? null;
  if ('languages' in body && body.languages !== undefined) input.languages = body.languages;
  if ('interests' in body && body.interests !== undefined) input.interests = body.interests;
  if ('currentCity' in body) input.currentCity = body.currentCity ?? null;
  if ('travelerType' in body) input.travelerType = body.travelerType ?? null;

  return input;
};

export class UserController {
  constructor(
    private readonly getUser: GetUserUseCase,
    private readonly updateProfile: UpdateUserProfileUseCase,
    private readonly clock: Clock,
    private readonly getUserCapabilities: GetUserCapabilitiesUseCase,
    private readonly deleteAccount: DeleteAccountUseCase,
  ) {}

  get = async (c: Context, id: string) => {
    const { user, isVerified } = await this.getUser.execute({ id });
    return c.json(toResponse(user, isVerified), 200);
  };

  getMyCapabilities = async (c: Context<{ Variables: AuthVariables }>) => {
    const userId = c.var.userId;
    const result = await this.getUserCapabilities.execute({ userId });
    return c.json(result);
  };

  patchMe = async (c: Context<{ Variables: AuthVariables }>, body: UpdateUserProfileBody) => {
    const userId = c.var.userId;
    const input = buildUpdateInput(userId, body, this.clock.now());

    await this.updateProfile.execute(input);

    const { user, isVerified } = await this.getUser.execute({ id: userId });
    return c.json(toResponse(user, isVerified), 200);
  };

  /**
   * DELETE /users/me — irreversible PDPA account-deletion cascade.
   *
   * Returns 204 No Content on success.
   * Returns 409 (CONFLICT / ACCOUNT_ALREADY_DELETED) if the account is already deleted.
   * Returns 401 if the bearer token is missing or invalid (requireAuth middleware).
   * Returns 500 on cascade failure (rolled-back; failure audit row written in a
   * clean second transaction for PDPA evidence trail).
   *
   * NOT guarded by requireVerifiedEmail — per CEO P3 ruling, an unverified
   * user must still be able to request erasure.
   */
  deleteMe = async (c: Context<{ Variables: AuthVariables }>) => {
    const userId = c.var.userId;
    await this.deleteAccount.execute({ userId });
    return c.body(null, 204);
  };
}

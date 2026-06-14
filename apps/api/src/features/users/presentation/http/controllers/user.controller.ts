import type { Context } from 'hono';
import type { FileStorage } from '@/core/storage/file-storage.port.js';
import { resolveAvatarReadUrl } from '@/core/storage/resolve-avatar-read-url.js';
import type { GetUserResult } from '../../../application/dto/get-user-result.dto.js';
import type { GetUserUseCase } from '../../../application/usecases/get-user.usecase.js';
import type { GetUserCapabilitiesUseCase } from '../../../application/usecases/get-user-capabilities.usecase.js';
import type { UpdateUserProfileInput } from '../../../application/usecases/update-user-profile.usecase.js';
import type { UpdateUserProfileUseCase } from '../../../application/usecases/update-user-profile.usecase.js';
import type { DeleteAccountUseCase } from '../../../application/usecases/delete-account.usecase.js';
import type { RequestAvatarUploadUseCase } from '../../../application/usecases/request-avatar-upload.usecase.js';
import type { ConfirmAvatarUploadUseCase } from '../../../application/usecases/confirm-avatar-upload.usecase.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import type { AuthVariables } from '@/core/middleware/require-auth.js';
import type { UpdateUserProfileBody, UserResponse } from '../schemas/user.schemas.js';

const toResponse = async (
  fileStorage: FileStorage,
  result: GetUserResult,
): Promise<UserResponse> => ({
  id: result.user.id,
  email: result.user.email.value,
  displayName: result.user.displayName.value,
  emailVerifiedAt: result.user.emailVerifiedAt?.toISOString() ?? null,
  isVerified: result.isVerified,
  bio: result.user.bio?.value ?? null,
  avatarUrl: await resolveAvatarReadUrl(fileStorage, result.user.avatarUrl?.value ?? null),
  languages: result.user.languages.map((l) => l.value),
  interests: result.user.interests.map((i) => i.value),
  currentCity: result.user.currentCity?.value ?? null,
  travelerType: result.user.travelerType?.value ?? null,
  createdAt: result.user.createdAt.toISOString(),
  updatedAt: result.user.updatedAt.toISOString(),
  averageRating: result.averageRating,
  reviewCount: result.reviewCount,
  recentVisibleComments: result.recentVisibleComments.map((c) => ({
    excerpt: c.excerpt,
    raterDisplayName: c.raterDisplayName,
    rating: c.rating,
    eventTitle: c.eventTitle,
    createdAt: c.createdAt.toISOString(),
  })),
});

/**
 * Build a use-case input object with patch semantics: only keys present in
 * the request body are forwarded. Under exactOptionalPropertyTypes, spreading
 * the Zod-parsed body would inject `undefined` for absent optional keys, which
 * the use case interface doesn't accept. Building explicitly preserves the
 * "absent key = don't touch" contract.
 *
 * Note: `avatarUrl` is intentionally absent here — avatar updates go through
 * the dedicated POST /users/me/avatar + POST /users/me/avatar/confirm pipeline
 * (TRI-24). Accepting an arbitrary URL on the PATCH endpoint is closed.
 */
const buildUpdateInput = (
  userId: string,
  body: UpdateUserProfileBody,
  now: Date,
): UpdateUserProfileInput => {
  const input: UpdateUserProfileInput = { userId, now };

  if ('bio' in body) input.bio = body.bio ?? null;
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
    private readonly fileStorage: FileStorage,
    private readonly requestAvatarUpload: RequestAvatarUploadUseCase,
    private readonly confirmAvatarUpload: ConfirmAvatarUploadUseCase,
  ) {}

  get = async (c: Context, id: string, viewerId?: string) => {
    const result = await this.getUser.execute(viewerId !== undefined ? { id, viewerId } : { id });
    return c.json(await toResponse(this.fileStorage, result), 200);
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

    const result = await this.getUser.execute({ id: userId, viewerId: userId });
    return c.json(await toResponse(this.fileStorage, result), 200);
  };

  requestAvatarUploadAction = async (c: Context<{ Variables: AuthVariables }>) => {
    const userId = c.var.userId;
    const result = await this.requestAvatarUpload.execute({ userId });
    return c.json(result, 200);
  };

  confirmAvatarUploadAction = async (
    c: Context<{ Variables: AuthVariables }>,
    storageKey: string,
  ) => {
    const userId = c.var.userId;
    const { user } = await this.confirmAvatarUpload.execute({ userId, storageKey });

    // Re-fetch via GetUserUseCase to get the full result shape (isVerified, ratings, etc.).
    const result = await this.getUser.execute({ id: user.id, viewerId: userId });
    return c.json(await toResponse(this.fileStorage, result), 200);
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

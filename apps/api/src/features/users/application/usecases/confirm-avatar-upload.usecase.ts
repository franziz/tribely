import { AppError } from '@/core/errors/app-error.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { FileStorage } from '@/core/storage/file-storage.port.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';
import type { User } from '../../domain/entities/user.js';

export interface ConfirmAvatarUploadInput {
  userId: string;
  storageKey: string;
}

export interface ConfirmAvatarUploadResult {
  user: User;
}

/**
 * Records a confirmed avatar upload against the authenticated user.
 *
 * Guards:
 *   - `storageKey` prefix !== `avatars/<userId>/` → 403 FORBIDDEN (key doesn't
 *     belong to this user — rejects cross-user key injection, mirrors SubmitSelfieUseCase).
 *
 * On success:
 *   1. Loads the User aggregate.
 *   2. Captures the prior avatar storage key (for best-effort cleanup).
 *   3. Calls `user.updateProfile({ avatarUrl: storageKey, now })` to persist the new key.
 *   4. Saves + publishes atomically inside a UnitOfWork.
 *   5. After commit, best-effort deletes the prior key from storage (orphan-tolerant —
 *      failure is caught, logged, and never re-thrown).
 *
 * Returns the updated User so the controller can render a fresh signed-URL response.
 */
export class ConfirmAvatarUploadUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly events: EventPublisher,
    private readonly fileStorage: FileStorage,
    private readonly logger: Logger,
  ) {}

  async execute(input: ConfirmAvatarUploadInput): Promise<ConfirmAvatarUploadResult> {
    // Validate storageKey ownership before hitting the DB.
    const expectedPrefix = `avatars/${input.userId}/`;
    if (!input.storageKey.startsWith(expectedPrefix)) {
      throw AppError.forbidden('storageKey does not belong to this user', {
        userId: input.userId,
        storageKey: input.storageKey,
      });
    }

    const { user, priorKey } = await this.unitOfWork.run(async (ctx) => {
      const found = await this.users.findById(input.userId, ctx);
      if (!found) throw AppError.notFound(`User ${input.userId} not found`);

      // Capture the prior avatar key before mutation so we can clean it up
      // after commit (outside the transaction — S3 delete is best-effort).
      const prior = found.avatarUrl?.value ?? null;

      // updateProfile validates the key via AvatarUrl.create() — throws on invalid.
      found.updateProfile({ avatarUrl: input.storageKey, now: new Date() });

      await this.users.save(found, ctx);
      await this.events.publish(ctx, ...found.pullEvents());

      return { user: found, priorKey: prior };
    });

    // Best-effort prior-key cleanup — runs OUTSIDE the transaction.
    // Never throws: an orphaned object is tolerable; a broken response is not.
    if (priorKey !== null && priorKey !== input.storageKey) {
      try {
        await this.fileStorage.deleteObject({ key: priorKey });
      } catch (err: unknown) {
        this.logger.warn(
          {
            userId: input.userId,
            priorKey,
            error: err instanceof Error ? err.message : String(err),
          },
          'ConfirmAvatarUploadUseCase: failed to delete prior avatar key',
        );
      }
    }

    return { user };
  }
}

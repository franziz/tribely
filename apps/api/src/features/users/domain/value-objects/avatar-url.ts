import { AppError } from '@/core/errors/app-error.js';

/**
 * AvatarUrl value object.
 *
 * Holds a **storage key** pointing to the user's avatar image in the binary
 * object store (e.g. `avatars/<userId>/<imageId>.jpg`). The name `AvatarUrl`
 * is intentionally kept as-is: the field name `avatarUrl` is the established
 * wire contract and renaming the VO without renaming the field would be more
 * confusing, not less. Leave a note here: this VO stores a storage key, not a
 * URL. The HTTP layer resolves it to a presigned URL via `resolveAvatarReadUrl`
 * before sending a response (TRI-24).
 *
 * Key format: `avatars/<userId>/<imageId>.jpg`
 * where userId and imageId are cuid2 strings (`[a-z0-9]+`).
 *
 * Accepts only storage keys matching `^avatars/[a-z0-9]+/[a-z0-9]+\.jpg$`.
 * Max 256 characters (well within any sane S3 key length).
 */
export class AvatarUrl {
  static readonly MAX = 256;
  /** Storage-key format: avatars/<cuid2>/<cuid2>.jpg */
  private static readonly KEY_PATTERN = /^avatars\/[a-z0-9]+\/[a-z0-9]+\.jpg$/;

  private constructor(public readonly value: string) {}

  static create(raw: string): AvatarUrl {
    const trimmed = raw.trim();
    if (trimmed.length === 0) {
      throw AppError.validation('Avatar storage key must not be empty');
    }
    if (trimmed.length > AvatarUrl.MAX) {
      throw AppError.validation(
        `Avatar storage key must be at most ${String(AvatarUrl.MAX)} characters`,
      );
    }
    if (!AvatarUrl.KEY_PATTERN.test(trimmed)) {
      throw AppError.validation(
        `Avatar storage key must match avatars/<userId>/<imageId>.jpg: ${raw}`,
      );
    }
    return new AvatarUrl(trimmed);
  }

  equals(other: AvatarUrl): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}

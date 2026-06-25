import type { FileStorage } from './file-storage.port.js';

/**
 * Resolves a storage key to a presigned read URL for an avatar image.
 *
 * Returns `null` when `key` is null (no avatar set). Otherwise generates a
 * presigned GET URL valid for 3600 seconds (1 hour) — matching the default
 * `readUrlMaxSeconds` cap configured in the DI container.
 *
 * Called at every emission site where `avatarUrl` leaves the server so that
 * mobile `NetworkImage` consumers always receive a fetchable signed URL, not
 * a raw storage key.
 */
export async function resolveAvatarReadUrl(
  fileStorage: FileStorage,
  key: string | null,
): Promise<string | null> {
  if (key === null) return null;
  return fileStorage.getSignedUrl({ key, expiresInSeconds: 3600 });
}

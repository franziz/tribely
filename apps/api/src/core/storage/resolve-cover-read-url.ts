import type { FileStorage } from './file-storage.port.js';

/**
 * Resolves a storage key to a presigned read URL for an event cover photo.
 *
 * Returns `null` when `key` is null (no cover photo set). Otherwise generates
 * a presigned GET URL valid for 3600 seconds (1 hour) — matching the default
 * `readUrlMaxSeconds` cap configured in the DI container.
 *
 * Called at every emission site where `coverPhotoStorageKey` leaves the server
 * so that mobile `NetworkImage` consumers always receive a fetchable signed
 * URL, not a raw storage key.
 */
export async function resolveCoverReadUrl(
  fileStorage: FileStorage,
  key: string | null,
): Promise<string | null> {
  if (key === null) return null;
  return fileStorage.getSignedUrl({ key, expiresInSeconds: 3600 });
}

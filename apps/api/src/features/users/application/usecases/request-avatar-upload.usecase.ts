import { createId } from '@paralleldrive/cuid2';
import type { FileStorage } from '@/core/storage/file-storage.port.js';

export interface RequestAvatarUploadInput {
  userId: string;
}

export interface RequestAvatarUploadResult {
  uploadUrl: string;
  storageKey: string;
}

/**
 * Generates a presigned S3 PUT URL so the mobile client can upload an avatar
 * image directly to storage without routing the binary through the API server.
 *
 * Does NOT persist any DB rows — the User aggregate's avatarUrl is updated by
 * ConfirmAvatarUploadUseCase once the client confirms the upload succeeded.
 *
 * Key format: `avatars/<userId>/<imageId>.jpg`
 *
 * The presigned URL is valid for 300 seconds (5 minutes). Content-Type is
 * bound into the signature as `image/jpeg` — the mobile client MUST include
 * a matching `Content-Type: image/jpeg` header on the PUT request.
 */
export class RequestAvatarUploadUseCase {
  constructor(private readonly fileStorage: FileStorage) {}

  async execute(input: RequestAvatarUploadInput): Promise<RequestAvatarUploadResult> {
    const imageId = createId();
    const storageKey = `avatars/${input.userId}/${imageId}.jpg`;

    const uploadUrl = await this.fileStorage.getSignedUploadUrl({
      key: storageKey,
      contentType: 'image/jpeg',
      expiresInSeconds: 300,
    });

    return { uploadUrl, storageKey };
  }
}

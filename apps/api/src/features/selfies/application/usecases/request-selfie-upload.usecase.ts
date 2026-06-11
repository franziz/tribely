import { createId } from '@paralleldrive/cuid2';
import type { FileStorage } from '@/core/storage/file-storage.port.js';
import type { RequestSelfieUploadResult } from '../dto/request-selfie-upload.result.js';

export interface RequestSelfieUploadInput {
  userId: string;
}

/**
 * Generates a presigned S3 PUT URL so the mobile client can upload a selfie
 * directly to storage without routing the binary through the API server.
 *
 * Does NOT persist any DB rows — the Selfie aggregate is created by
 * SubmitSelfieUseCase once the client confirms the upload succeeded.
 *
 * Key format: `uploads/<userId>/<selfieId>.jpg`
 *
 * The presigned URL is valid for 300 seconds (5 minutes). Content-Type is
 * bound into the signature as `image/jpeg` — the mobile client MUST include
 * a matching `Content-Type: image/jpeg` header on the PUT request.
 */
export class RequestSelfieUploadUseCase {
  constructor(private readonly fileStorage: FileStorage) {}

  async execute(input: RequestSelfieUploadInput): Promise<RequestSelfieUploadResult> {
    const selfieId = createId();
    const storageKey = `uploads/${input.userId}/${selfieId}.jpg`;

    const uploadUrl = await this.fileStorage.getSignedUploadUrl({
      key: storageKey,
      contentType: 'image/jpeg',
      expiresInSeconds: 300,
    });

    return { uploadUrl, storageKey };
  }
}

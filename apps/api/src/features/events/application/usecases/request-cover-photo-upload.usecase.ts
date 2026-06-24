import { createId } from '@paralleldrive/cuid2';
import { AppError } from '@/core/errors/app-error.js';
import type { FileStorage } from '@/core/storage/file-storage.port.js';
import type {
  RequestCoverPhotoUploadInput,
  RequestCoverPhotoUploadResult,
} from '../dto/request-cover-photo-upload.dto.js';

export type { RequestCoverPhotoUploadInput, RequestCoverPhotoUploadResult };

const ALLOWED_CONTENT_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
type AllowedContentType = (typeof ALLOWED_CONTENT_TYPES)[number];

const EXT_MAP: Record<AllowedContentType, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

const isAllowedContentType = (ct: string): ct is AllowedContentType =>
  (ALLOWED_CONTENT_TYPES as readonly string[]).includes(ct);

/**
 * Generates a presigned S3 PUT URL so the mobile client can upload an event
 * cover photo directly to storage without routing the binary through the API
 * server.
 *
 * Does NOT persist any DB rows — the cover photo storage key is fused into the
 * Event aggregate when the host calls POST /events with `coverPhotoStorageKey`
 * in the body.
 *
 * Key format: `events/<hostUserId>/<imageId>.<ext>`
 *
 * The presigned URL is valid for 300 seconds (5 minutes). The ownership-guard
 * prefix `events/<hostUserId>/` is enforced at event-creation time by
 * CreateEventUseCase (security-critical).
 *
 * Supports: image/jpeg → .jpg, image/png → .png, image/webp → .webp.
 */
export class RequestCoverPhotoUploadUseCase {
  constructor(private readonly fileStorage: FileStorage) {}

  async execute(
    input: RequestCoverPhotoUploadInput,
  ): Promise<RequestCoverPhotoUploadResult> {
    if (!isAllowedContentType(input.contentType)) {
      throw AppError.validation(
        `contentType must be one of: ${ALLOWED_CONTENT_TYPES.join(', ')}`,
        { contentType: input.contentType },
      );
    }

    const ext = EXT_MAP[input.contentType];
    const imageId = createId();
    const storageKey = `events/${input.hostUserId}/${imageId}.${ext}`;

    const uploadUrl = await this.fileStorage.getSignedUploadUrl({
      key: storageKey,
      contentType: input.contentType,
      expiresInSeconds: 300,
    });

    return { uploadUrl, storageKey };
  }
}

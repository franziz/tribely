/**
 * Production adapter backed by AWS S3 (and S3-compatible endpoints, e.g. ap-southeast-1
 * for the Singapore-first launch — see TRI-77).
 *
 * THIS IS THE ONLY FILE IN THE REPO ALLOWED TO IMPORT '@aws-sdk/client-s3' OR
 * '@aws-sdk/s3-request-presigner'. All other files must consume the FileStorage
 * port instead. An ESLint no-restricted-imports rule enforces this boundary at
 * lint time.
 *
 * Design decisions:
 * - Duck-type error detection (isS3NotFoundError) rather than
 *   `instanceof S3ServiceException`. S3ServiceException is an abstract base class;
 *   concrete error subclasses (NoSuchKey, NoSuchBucket, etc.) hit instanceof checks
 *   differently depending on whether the caller imported the same class reference
 *   that the SDK used to construct the error. In Vitest + ESM that identity
 *   guarantee breaks across mock boundaries. Duck-typing on `name` and
 *   `$metadata.httpStatusCode` is both safer and keeps the guard free from SDK
 *   internal type hierarchies that may change across major versions.
 * - Cap enforcement: `readUrlMaxSeconds` and `uploadUrlMaxSeconds` are constructor
 *   arguments supplied by the DI container (defaults 3600 and 300 respectively).
 *   Any caller-supplied `expiresInSeconds` that exceeds the cap throws immediately
 *   — BEFORE the presigner call — with both the requested and allowed values in the
 *   error message so the caller can diagnose without digging into logs.
 * - `getSignedUploadUrl` binds `signableHeaders: new Set(['content-type'])`. Without
 *   this, S3 will accept uploads with any Content-Type regardless of what was
 *   specified when the URL was generated, making content-type validation trivially
 *   bypassable. With it, the client MUST send the exact matching header or S3
 *   returns 403 SignatureDoesNotMatch.
 * - No SSE per-object headers — bucket-default encryption applies. This keeps the
 *   adapter free from encryption-config coupling and lets the bucket policy evolve
 *   independently.
 * - No retry/backoff inside the adapter — that is the caller's concern.
 * - `verifyReachable()` is adapter-specific (not on the FileStorage port). It is
 *   intended as a boot-time probe to surface misconfiguration early, before the
 *   first real request.
 * - Unit tests in `s3-file-storage.test.ts` do NOT import `@aws-sdk/*` either —
 *   they assert command shape via runtime introspection (`.constructor.name` +
 *   `.input`). The integration test (`s3-file-storage.integration.test.ts`) is
 *   exempt from the ESLint gate and is the real wire-shape safety net.
 */
import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadBucketCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl as awsGetSignedUrl } from '@aws-sdk/s3-request-presigner';
import { AppError } from '@/core/errors/app-error.js';
import type { FileStorage } from './file-storage.port.js';

// ---------------------------------------------------------------------------
// Duck-type error detection
// ---------------------------------------------------------------------------

interface S3ErrorShape {
  readonly name?: string;
  readonly $metadata?: { readonly httpStatusCode?: number };
}

function isS3NotFoundError(e: unknown): boolean {
  if (typeof e !== 'object' || e === null) return false;
  const err = e as S3ErrorShape;
  if (err.name === 'NoSuchKey') return true;
  if (err.$metadata?.httpStatusCode === 404) return true;
  return false;
}

// ---------------------------------------------------------------------------
// Adapter
// ---------------------------------------------------------------------------

export interface S3FileStorageConfig {
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
  readUrlMaxSeconds: number;
  uploadUrlMaxSeconds: number;
  /** S3-compatible endpoint override (R2, B2, MinIO). Optional. */
  endpoint?: string;
  /** Use path-style URLs — required for MinIO and some S3-compatible stores. */
  forcePathStyle?: boolean;
}

export class S3FileStorageAdapter implements FileStorage {
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly readUrlMaxSeconds: number;
  private readonly uploadUrlMaxSeconds: number;

  constructor(input: {
    client: S3Client;
    bucket: string;
    readUrlMaxSeconds: number;
    uploadUrlMaxSeconds: number;
  }) {
    this.client = input.client;
    this.bucket = input.bucket;
    this.readUrlMaxSeconds = input.readUrlMaxSeconds;
    this.uploadUrlMaxSeconds = input.uploadUrlMaxSeconds;
  }

  /**
   * Factory that constructs an S3Client from raw credentials, keeping all
   * @aws-sdk/client-s3 imports contained within this file (enforced by
   * ESLint no-restricted-imports). DI container callers use this rather
   * than importing S3Client directly.
   */
  static fromConfig(config: S3FileStorageConfig): S3FileStorageAdapter {
    const client = new S3Client({
      region: config.region,
      credentials: {
        accessKeyId: config.accessKeyId,
        secretAccessKey: config.secretAccessKey,
      },
      ...(config.endpoint ? { endpoint: config.endpoint } : {}),
      ...(config.forcePathStyle ? { forcePathStyle: true } : {}),
    });
    return new S3FileStorageAdapter({
      client,
      bucket: config.bucket,
      readUrlMaxSeconds: config.readUrlMaxSeconds,
      uploadUrlMaxSeconds: config.uploadUrlMaxSeconds,
    });
  }

  async putObject(input: { key: string; body: Buffer; contentType: string }): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: input.key,
        Body: input.body,
        ContentType: input.contentType,
      }),
    );
  }

  async deleteObject(input: { key: string }): Promise<void> {
    try {
      await this.client.send(
        new DeleteObjectCommand({
          Bucket: this.bucket,
          Key: input.key,
        }),
      );
    } catch (e: unknown) {
      if (isS3NotFoundError(e)) return;
      throw e;
    }
  }

  async getSignedUrl(input: { key: string; expiresInSeconds: number }): Promise<string> {
    if (input.expiresInSeconds > this.readUrlMaxSeconds) {
      throw new Error(
        `getSignedUrl: requested expiresInSeconds (${String(input.expiresInSeconds)}) exceeds the adapter cap (${String(this.readUrlMaxSeconds)})`,
      );
    }
    return awsGetSignedUrl(
      this.client,
      new GetObjectCommand({ Bucket: this.bucket, Key: input.key }),
      { expiresIn: input.expiresInSeconds },
    );
  }

  async getSignedUploadUrl(input: {
    key: string;
    contentType: string;
    expiresInSeconds: number;
  }): Promise<string> {
    if (input.expiresInSeconds > this.uploadUrlMaxSeconds) {
      throw new Error(
        `getSignedUploadUrl: requested expiresInSeconds (${String(input.expiresInSeconds)}) exceeds the adapter cap (${String(this.uploadUrlMaxSeconds)})`,
      );
    }
    return awsGetSignedUrl(
      this.client,
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: input.key,
        ContentType: input.contentType,
      }),
      {
        expiresIn: input.expiresInSeconds,
        signableHeaders: new Set(['content-type']),
      },
    );
  }

  async getObjectSize(input: { key: string }): Promise<number> {
    try {
      const result = await this.client.send(
        new HeadObjectCommand({ Bucket: this.bucket, Key: input.key }),
      );
      // ContentLength is typed as number | undefined by the SDK. A successful
      // HEAD on an existing object must return it; treat its absence as an
      // internal error rather than returning 0 and silently hiding a problem.
      if (result.ContentLength === undefined) {
        throw new Error(`HeadObject for "${input.key}" returned no ContentLength`);
      }
      return result.ContentLength;
    } catch (e: unknown) {
      if (isS3NotFoundError(e)) {
        throw AppError.notFound(`Storage object not found: ${input.key}`, { key: input.key });
      }
      throw e;
    }
  }

  async verifyReachable(): Promise<void> {
    try {
      await this.client.send(new HeadBucketCommand({ Bucket: this.bucket }));
    } catch (e: unknown) {
      const originalMessage = e instanceof Error ? e.message : String(e);
      throw new Error(
        `S3FileStorageAdapter: bucket "${this.bucket}" is not reachable — ${originalMessage}`,
        { cause: e },
      );
    }
  }
}

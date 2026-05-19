// Load apps/api/.env into process.env before anything reads it.
// Vitest does NOT auto-load .env (see CLAUDE.md gotcha). Without this import,
// STORAGE_TEST_* vars are undefined even when set in .env and every test
// silently skips.
import 'dotenv/config';
import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { S3Client } from '@aws-sdk/client-s3';
import { S3FileStorageAdapter } from './s3-file-storage.js';

/**
 * Opt-in integration test — hits a real AWS S3 bucket.
 *
 * To run:
 *   STORAGE_TEST_BUCKET=<bucket> \
 *   STORAGE_TEST_REGION=<region> \
 *   STORAGE_TEST_ACCESS_KEY_ID=<key-id> \
 *   STORAGE_TEST_SECRET_ACCESS_KEY=<secret> \
 *   npm run --workspace=@tribely/api test -- \
 *     src/core/storage/s3-file-storage.integration.test.ts
 *
 * Use a dedicated sandbox bucket — NOT the production selfie bucket.
 * These vars are intentionally SEPARATE from the production STORAGE_* vars so
 * engineers can run the suite without disrupting their local app config.
 *
 * This test intentionally does NOT run in CI (no STORAGE_TEST_* secrets in
 * GitHub Actions). Local-only, opt-in. All created objects are cleaned up
 * in afterEach/afterAll blocks.
 *
 * Tests:
 *   1. putObject → getSignedUrl → fetch → bytes match → deleteObject → fetch 404
 *   2. getSignedUploadUrl → PUT with correct Content-Type → getSignedUrl → bytes match
 *   3. getSignedUploadUrl → PUT with wrong Content-Type → 403
 *   4. deleteObject on a nonexistent key → void (idempotent)
 *   5. getSignedUrl with expiresInSeconds above cap → throws
 *   6. verifyReachable against the test bucket → resolves
 *   7. verifyReachable against a nonexistent bucket → throws
 */

const HAS_CREDS =
  !!process.env.STORAGE_TEST_BUCKET &&
  !!process.env.STORAGE_TEST_REGION &&
  !!process.env.STORAGE_TEST_ACCESS_KEY_ID &&
  !!process.env.STORAGE_TEST_SECRET_ACCESS_KEY;

const TEST_BUCKET = process.env.STORAGE_TEST_BUCKET ?? '';
const TEST_REGION = process.env.STORAGE_TEST_REGION ?? 'ap-southeast-1';
const ACCESS_KEY_ID = process.env.STORAGE_TEST_ACCESS_KEY_ID ?? '';
const SECRET_ACCESS_KEY = process.env.STORAGE_TEST_SECRET_ACCESS_KEY ?? '';

/** Default caps — same as what DI wires for production. */
const READ_URL_MAX_SECONDS = 3600;
const UPLOAD_URL_MAX_SECONDS = 300;

/** Prefix all test keys so they are identifiable and easy to clean up. */
const KEY_PREFIX = `integration-test/${String(Date.now())}/`;

/** Keys created during this run — collected for afterAll cleanup. */
const createdKeys: string[] = [];

function makeClient(): S3Client {
  return new S3Client({
    region: TEST_REGION,
    credentials: {
      accessKeyId: ACCESS_KEY_ID,
      secretAccessKey: SECRET_ACCESS_KEY,
    },
  });
}

function makeAdapter(overrides?: { readUrlMaxSeconds?: number; uploadUrlMaxSeconds?: number }): S3FileStorageAdapter {
  return new S3FileStorageAdapter({
    client: makeClient(),
    bucket: TEST_BUCKET,
    readUrlMaxSeconds: overrides?.readUrlMaxSeconds ?? READ_URL_MAX_SECONDS,
    uploadUrlMaxSeconds: overrides?.uploadUrlMaxSeconds ?? UPLOAD_URL_MAX_SECONDS,
  });
}

/** Track a key so afterEach/afterAll can delete it even if the test fails. */
function track(key: string): string {
  createdKeys.push(key);
  return key;
}

describe('S3FileStorageAdapter (integration — real S3 bucket)', () => {
  let adapter: S3FileStorageAdapter;

  beforeAll(() => {
    if (!HAS_CREDS) return;
    adapter = makeAdapter();
  });

  afterEach(async () => {
    if (!HAS_CREDS) return;
    // Clean up any keys created during the test. Silently ignore errors —
    // deleteObject is idempotent and a failed cleanup should not mask the
    // actual test outcome.
    const cleanup = adapter;
    await Promise.allSettled(
      createdKeys.splice(0).map((key) => cleanup.deleteObject({ key })),
    );
  });

  // -------------------------------------------------------------------------
  // Test 1 — putObject full lifecycle
  // -------------------------------------------------------------------------
  it.skipIf(!HAS_CREDS)(
    'putObject → getSignedUrl → fetch → bytes match → deleteObject → fetch 404',
    async () => {
      const key = track(`${KEY_PREFIX}test-1-put-get-delete.txt`);
      const body = Buffer.from('hello tribely integration test');
      const contentType = 'text/plain';

      // Upload
      await adapter.putObject({ key, body, contentType });

      // Presign a read URL and fetch
      const readUrl = await adapter.getSignedUrl({ key, expiresInSeconds: 60 });
      const fetchAfterPut = await fetch(readUrl);
      expect(fetchAfterPut.status).toBe(200);
      const fetchedBytes = Buffer.from(await fetchAfterPut.arrayBuffer());
      expect(fetchedBytes).toEqual(body);

      // Delete
      await adapter.deleteObject({ key });

      // Presign a new URL (presigning does NOT verify key existence — the URL
      // is valid but the object is gone, so fetch returns 404).
      const readUrlAfterDelete = await adapter.getSignedUrl({ key, expiresInSeconds: 60 });
      const fetchAfterDelete = await fetch(readUrlAfterDelete);
      expect(fetchAfterDelete.status).toBe(404);
    },
    30_000,
  );

  // -------------------------------------------------------------------------
  // Test 2 — getSignedUploadUrl with correct Content-Type
  // -------------------------------------------------------------------------
  it.skipIf(!HAS_CREDS)(
    'getSignedUploadUrl → PUT with matching Content-Type → 2xx → getSignedUrl → bytes match',
    async () => {
      const key = track(`${KEY_PREFIX}test-2-presigned-upload.png`);
      const body = Buffer.from('fake-png-bytes');
      const contentType = 'image/png';

      // Get a presigned upload URL
      const uploadUrl = await adapter.getSignedUploadUrl({ key, contentType, expiresInSeconds: 60 });

      // HTTP PUT with the exact matching Content-Type
      const putResponse = await fetch(uploadUrl, {
        method: 'PUT',
        body,
        headers: { 'Content-Type': contentType },
      });
      expect(putResponse.status).toBeGreaterThanOrEqual(200);
      expect(putResponse.status).toBeLessThan(300);

      // Read back via presigned URL and verify bytes match
      const readUrl = await adapter.getSignedUrl({ key, expiresInSeconds: 60 });
      const fetchResponse = await fetch(readUrl);
      expect(fetchResponse.status).toBe(200);
      const fetchedBytes = Buffer.from(await fetchResponse.arrayBuffer());
      expect(fetchedBytes).toEqual(body);
    },
    30_000,
  );

  // -------------------------------------------------------------------------
  // Test 3 — getSignedUploadUrl with wrong Content-Type → 403
  // -------------------------------------------------------------------------
  it.skipIf(!HAS_CREDS)(
    'getSignedUploadUrl → PUT with wrong Content-Type → 403 SignatureDoesNotMatch',
    async () => {
      const key = track(`${KEY_PREFIX}test-3-presigned-upload-wrong-ct.png`);
      const contentType = 'image/png';

      // Get a presigned upload URL bound to image/png
      const uploadUrl = await adapter.getSignedUploadUrl({ key, contentType, expiresInSeconds: 60 });

      // PUT with a DIFFERENT Content-Type — S3 must reject with 403
      const putResponse = await fetch(uploadUrl, {
        method: 'PUT',
        body: Buffer.from('some bytes'),
        headers: { 'Content-Type': 'application/octet-stream' },
      });
      expect(putResponse.status).toBe(403);
    },
    30_000,
  );

  // -------------------------------------------------------------------------
  // Test 4 — deleteObject on a nonexistent key → void (idempotent)
  // -------------------------------------------------------------------------
  it.skipIf(!HAS_CREDS)(
    'deleteObject on a nonexistent key resolves to void without throwing',
    async () => {
      const key = `${KEY_PREFIX}test-4-nonexistent-key-${String(Date.now())}.txt`;
      // Key is deliberately NOT tracked — it will never exist in the bucket.
      await expect(adapter.deleteObject({ key })).resolves.toBeUndefined();
    },
    15_000,
  );

  // -------------------------------------------------------------------------
  // Test 5 — getSignedUrl above cap → throws
  // -------------------------------------------------------------------------
  it.skipIf(!HAS_CREDS)(
    'getSignedUrl with expiresInSeconds above the configured cap throws',
    async () => {
      const tightAdapter = makeAdapter({ readUrlMaxSeconds: 60 });
      const key = `${KEY_PREFIX}test-5-cap-check.txt`;

      await expect(
        tightAdapter.getSignedUrl({ key, expiresInSeconds: 61 }),
      ).rejects.toThrow('exceeds the adapter cap');
    },
    10_000,
  );

  // -------------------------------------------------------------------------
  // Test 6 — verifyReachable against the real test bucket → resolves
  // -------------------------------------------------------------------------
  it.skipIf(!HAS_CREDS)(
    'verifyReachable resolves for a reachable bucket',
    async () => {
      await expect(adapter.verifyReachable()).resolves.toBeUndefined();
    },
    15_000,
  );

  // -------------------------------------------------------------------------
  // Test 7 — verifyReachable against a nonexistent bucket → throws
  // -------------------------------------------------------------------------
  it.skipIf(!HAS_CREDS)(
    'verifyReachable throws for a nonexistent bucket',
    async () => {
      const badAdapter = new S3FileStorageAdapter({
        client: makeClient(),
        bucket: `${TEST_BUCKET}-nonexistent`,
        readUrlMaxSeconds: READ_URL_MAX_SECONDS,
        uploadUrlMaxSeconds: UPLOAD_URL_MAX_SECONDS,
      });

      await expect(badAdapter.verifyReachable()).rejects.toThrow(
        /S3FileStorageAdapter: bucket .* is not reachable/,
      );
    },
    15_000,
  );
});

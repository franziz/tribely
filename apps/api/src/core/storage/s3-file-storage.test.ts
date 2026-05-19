/**
 * Unit tests for S3FileStorageAdapter.
 *
 * IMPORTANT — this file intentionally does NOT import '@aws-sdk/client-s3' or
 * '@aws-sdk/s3-request-presigner' (not even type-only imports). An ESLint
 * no-restricted-imports rule gates those imports to the adapter file itself and
 * the integration test. Extending that exemption here would defeat the boundary.
 *
 * Command-shape verification uses runtime introspection: `.constructor.name`
 * identifies the command class and `.input` carries the parameters object.
 * String-literal names ('PutObjectCommand', 'GetObjectCommand', etc.) are
 * intentional — they are the stable SDK export names.
 *
 * The integration test (s3-file-storage.integration.test.ts) is the real safety
 * net for wire-shape correctness against a live-compatible endpoint.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';

// ---------------------------------------------------------------------------
// Minimal duck-type interface — mirrors what the adapter actually consumes.
// No @aws-sdk/* types needed.
// ---------------------------------------------------------------------------

interface FakeS3Client {
  send: ReturnType<typeof vi.fn>;
}

// ---------------------------------------------------------------------------
// Mock the presigner — stringly-typed factory, zero SDK imports.
// vi.hoisted captures the reference before the vi.mock() factory runs so we
// can use it both inside the factory and inside the test bodies.
// ---------------------------------------------------------------------------

const { mockGetSignedUrl } = vi.hoisted(() => ({
  mockGetSignedUrl: vi.fn<() => Promise<string>>(),
}));

vi.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: mockGetSignedUrl,
}));

// Import adapter AFTER vi.mock so it picks up the mocked presigner.
const { S3FileStorageAdapter } = await import('./s3-file-storage.js');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const BUCKET = 'tribely-selfies-test';
const DEFAULT_CONFIG = {
  bucket: BUCKET,
  readUrlMaxSeconds: 3600,
  uploadUrlMaxSeconds: 300,
};

/** Build a minimal S3Client stub with a `send` vitest mock. */
function makeClientStub(): FakeS3Client {
  return { send: vi.fn() };
}

function makeAdapter(client: FakeS3Client, overrides: Partial<typeof DEFAULT_CONFIG> = {}) {
  // Cast through unknown: FakeS3Client satisfies the duck-type the adapter consumes
  // (only `send` is called). The ESLint gate prevents importing the real S3Client type.
  return new S3FileStorageAdapter({
    client: client as unknown as ConstructorParameters<typeof S3FileStorageAdapter>[0]['client'],
    ...DEFAULT_CONFIG,
    ...overrides,
  });
}

// ---------------------------------------------------------------------------
// putObject
// ---------------------------------------------------------------------------

describe('putObject', () => {
  let send: ReturnType<typeof vi.fn>;
  let client: FakeS3Client;

  beforeEach(() => {
    client = makeClientStub();
    send = client.send;
    send.mockResolvedValue({});
  });

  it('sends a PutObjectCommand with Bucket, Key, Body, and ContentType', async () => {
    const adapter = makeAdapter(client);
    const body = Buffer.from('selfie-bytes');

    await adapter.putObject({ key: 'selfies/user-1/sub-1.jpg', body, contentType: 'image/jpeg' });

    expect(send).toHaveBeenCalledTimes(1);
    const callArg: unknown = send.mock.calls[0]?.[0];
    expect((callArg as { constructor: { name: string } }).constructor.name).toBe(
      'PutObjectCommand',
    );
    expect((callArg as { input: unknown }).input).toMatchObject({
      Bucket: BUCKET,
      Key: 'selfies/user-1/sub-1.jpg',
      Body: body,
      ContentType: 'image/jpeg',
    });
  });

  it('resolves to void on success', async () => {
    const adapter = makeAdapter(client);
    await expect(
      adapter.putObject({
        key: 'selfies/user-1/sub-1.jpg',
        body: Buffer.from('x'),
        contentType: 'image/jpeg',
      }),
    ).resolves.toBeUndefined();
  });

  it('rethrows errors from S3', async () => {
    const adapter = makeAdapter(client);
    send.mockRejectedValueOnce(new Error('AccessDenied'));
    await expect(
      adapter.putObject({
        key: 'selfies/user-1/sub-1.jpg',
        body: Buffer.from('x'),
        contentType: 'image/jpeg',
      }),
    ).rejects.toThrow('AccessDenied');
  });
});

// ---------------------------------------------------------------------------
// deleteObject
// ---------------------------------------------------------------------------

describe('deleteObject', () => {
  let send: ReturnType<typeof vi.fn>;
  let client: FakeS3Client;

  beforeEach(() => {
    client = makeClientStub();
    send = client.send;
    send.mockResolvedValue({});
  });

  it('sends a DeleteObjectCommand with Bucket and Key', async () => {
    const adapter = makeAdapter(client);
    await adapter.deleteObject({ key: 'selfies/user-1/sub-1.jpg' });

    expect(send).toHaveBeenCalledTimes(1);
    const callArg: unknown = send.mock.calls[0]?.[0];
    expect((callArg as { constructor: { name: string } }).constructor.name).toBe(
      'DeleteObjectCommand',
    );
    expect((callArg as { input: unknown }).input).toMatchObject({
      Bucket: BUCKET,
      Key: 'selfies/user-1/sub-1.jpg',
    });
  });

  it('resolves to void when S3 returns success', async () => {
    const adapter = makeAdapter(client);
    await expect(
      adapter.deleteObject({ key: 'selfies/user-1/sub-1.jpg' }),
    ).resolves.toBeUndefined();
  });

  it('swallows a NoSuchKey-shaped error (name === "NoSuchKey")', async () => {
    const adapter = makeAdapter(client);
    const notFound = Object.assign(new Error('NoSuchKey'), { name: 'NoSuchKey' });
    send.mockRejectedValueOnce(notFound);
    await expect(
      adapter.deleteObject({ key: 'selfies/user-1/sub-1.jpg' }),
    ).resolves.toBeUndefined();
  });

  it('swallows a 404-shaped error ($metadata.httpStatusCode === 404)', async () => {
    const adapter = makeAdapter(client);
    const notFound = Object.assign(new Error('NotFound'), {
      $metadata: { httpStatusCode: 404 },
    });
    send.mockRejectedValueOnce(notFound);
    await expect(
      adapter.deleteObject({ key: 'selfies/user-1/sub-1.jpg' }),
    ).resolves.toBeUndefined();
  });

  it('rethrows non-404 S3 errors', async () => {
    const adapter = makeAdapter(client);
    const accessDenied = Object.assign(new Error('AccessDenied'), {
      name: 'AccessDenied',
      $metadata: { httpStatusCode: 403 },
    });
    send.mockRejectedValueOnce(accessDenied);
    await expect(adapter.deleteObject({ key: 'selfies/user-1/sub-1.jpg' })).rejects.toThrow(
      'AccessDenied',
    );
  });

  it('rethrows plain Error objects that are not not-found shaped', async () => {
    const adapter = makeAdapter(client);
    send.mockRejectedValueOnce(new Error('InternalServerError'));
    await expect(adapter.deleteObject({ key: 'selfies/user-1/sub-1.jpg' })).rejects.toThrow(
      'InternalServerError',
    );
  });
});

// ---------------------------------------------------------------------------
// getSignedUrl
// ---------------------------------------------------------------------------

describe('getSignedUrl', () => {
  let client: FakeS3Client;

  beforeEach(() => {
    client = makeClientStub();
    mockGetSignedUrl.mockClear();
    mockGetSignedUrl.mockResolvedValue('https://s3.example.com/signed-read-url');
  });

  it('calls the presigner with a GetObjectCommand, correct expiresIn, Bucket, and Key', async () => {
    const adapter = makeAdapter(client);
    const url = await adapter.getSignedUrl({
      key: 'selfies/user-1/sub-1.jpg',
      expiresInSeconds: 900,
    });

    expect(mockGetSignedUrl).toHaveBeenCalledTimes(1);
    const calls = mockGetSignedUrl.mock.calls[0] as unknown[];
    const calledClient = calls[0];
    const calledCommand = calls[1] as { constructor: { name: string }; input: unknown };
    const calledOptions = calls[2] as { expiresIn: number };

    expect(calledClient).toBe(client);
    expect(calledCommand.constructor.name).toBe('GetObjectCommand');
    expect(calledCommand.input).toMatchObject({
      Bucket: BUCKET,
      Key: 'selfies/user-1/sub-1.jpg',
    });
    expect(calledOptions).toMatchObject({ expiresIn: 900 });
    expect(url).toBe('https://s3.example.com/signed-read-url');
  });

  it('passes through the presigner result', async () => {
    const adapter = makeAdapter(client);
    mockGetSignedUrl.mockResolvedValueOnce('https://custom-url.example.com/object');
    const url = await adapter.getSignedUrl({ key: 'any-key', expiresInSeconds: 60 });
    expect(url).toBe('https://custom-url.example.com/object');
  });

  it('throws when expiresInSeconds exceeds readUrlMaxSeconds — message includes both values', async () => {
    const adapter = makeAdapter(client, { readUrlMaxSeconds: 3600 });
    await expect(
      adapter.getSignedUrl({ key: 'selfies/user-1/sub-1.jpg', expiresInSeconds: 3601 }),
    ).rejects.toThrow('3601');
    await expect(
      adapter.getSignedUrl({ key: 'selfies/user-1/sub-1.jpg', expiresInSeconds: 3601 }),
    ).rejects.toThrow('3600');
    expect(mockGetSignedUrl).not.toHaveBeenCalled();
  });

  it('accepts expiresInSeconds exactly equal to the cap', async () => {
    const adapter = makeAdapter(client, { readUrlMaxSeconds: 3600 });
    await expect(
      adapter.getSignedUrl({ key: 'selfies/user-1/sub-1.jpg', expiresInSeconds: 3600 }),
    ).resolves.toBeDefined();
    expect(mockGetSignedUrl).toHaveBeenCalledTimes(1);
  });
});

// ---------------------------------------------------------------------------
// getSignedUploadUrl
// ---------------------------------------------------------------------------

describe('getSignedUploadUrl', () => {
  let client: FakeS3Client;

  beforeEach(() => {
    client = makeClientStub();
    mockGetSignedUrl.mockClear();
    mockGetSignedUrl.mockResolvedValue('https://s3.example.com/signed-upload-url');
  });

  it('calls the presigner with a PutObjectCommand, expiresIn, ContentType, and signableHeaders containing "content-type"', async () => {
    const adapter = makeAdapter(client);
    const url = await adapter.getSignedUploadUrl({
      key: 'selfies/user-1/sub-1.jpg',
      contentType: 'image/jpeg',
      expiresInSeconds: 180,
    });

    expect(mockGetSignedUrl).toHaveBeenCalledTimes(1);
    const calls = mockGetSignedUrl.mock.calls[0] as unknown[];
    const calledClient = calls[0];
    const calledCommand = calls[1] as { constructor: { name: string }; input: unknown };
    const calledOptions = calls[2] as { expiresIn: number; signableHeaders?: Set<string> };

    expect(calledClient).toBe(client);
    expect(calledCommand.constructor.name).toBe('PutObjectCommand');
    expect(calledCommand.input).toMatchObject({
      Bucket: BUCKET,
      Key: 'selfies/user-1/sub-1.jpg',
      ContentType: 'image/jpeg',
    });
    expect(calledOptions).toMatchObject({ expiresIn: 180 });
    expect(calledOptions.signableHeaders).toBeInstanceOf(Set);
    expect(calledOptions.signableHeaders?.has('content-type')).toBe(true);
    expect(url).toBe('https://s3.example.com/signed-upload-url');
  });

  it('throws when expiresInSeconds exceeds uploadUrlMaxSeconds — message includes both values', async () => {
    const adapter = makeAdapter(client, { uploadUrlMaxSeconds: 300 });
    await expect(
      adapter.getSignedUploadUrl({
        key: 'selfies/user-1/sub-1.jpg',
        contentType: 'image/jpeg',
        expiresInSeconds: 301,
      }),
    ).rejects.toThrow('301');
    await expect(
      adapter.getSignedUploadUrl({
        key: 'selfies/user-1/sub-1.jpg',
        contentType: 'image/jpeg',
        expiresInSeconds: 301,
      }),
    ).rejects.toThrow('300');
    expect(mockGetSignedUrl).not.toHaveBeenCalled();
  });

  it('accepts expiresInSeconds exactly equal to the cap', async () => {
    const adapter = makeAdapter(client, { uploadUrlMaxSeconds: 300 });
    await expect(
      adapter.getSignedUploadUrl({
        key: 'selfies/user-1/sub-1.jpg',
        contentType: 'image/png',
        expiresInSeconds: 300,
      }),
    ).resolves.toBeDefined();
    expect(mockGetSignedUrl).toHaveBeenCalledTimes(1);
  });
});

// ---------------------------------------------------------------------------
// verifyReachable
// ---------------------------------------------------------------------------

describe('verifyReachable', () => {
  let send: ReturnType<typeof vi.fn>;
  let client: FakeS3Client;

  beforeEach(() => {
    client = makeClientStub();
    send = client.send;
    send.mockResolvedValue({});
  });

  it('sends a HeadBucketCommand with the configured Bucket', async () => {
    const adapter = makeAdapter(client);
    await adapter.verifyReachable();

    expect(send).toHaveBeenCalledTimes(1);
    const callArg: unknown = send.mock.calls[0]?.[0];
    expect((callArg as { constructor: { name: string } }).constructor.name).toBe(
      'HeadBucketCommand',
    );
    expect((callArg as { input: unknown }).input).toMatchObject({ Bucket: BUCKET });
  });

  it('resolves to void when HeadBucket succeeds', async () => {
    const adapter = makeAdapter(client);
    await expect(adapter.verifyReachable()).resolves.toBeUndefined();
  });

  it('throws when client rejects — error message includes bucket name', async () => {
    const adapter = makeAdapter(client);
    send.mockRejectedValueOnce(new Error('NoSuchBucket'));

    await expect(adapter.verifyReachable()).rejects.toThrow(BUCKET);
  });

  it('wraps the original error message in the thrown error', async () => {
    const adapter = makeAdapter(client);
    send.mockRejectedValueOnce(new Error('network timeout'));

    await expect(adapter.verifyReachable()).rejects.toThrow('network timeout');
  });

  it('handles non-Error throws — converts to string in the message', async () => {
    const adapter = makeAdapter(client);
    send.mockRejectedValueOnce('connection refused');

    await expect(adapter.verifyReachable()).rejects.toThrow('connection refused');
  });
});

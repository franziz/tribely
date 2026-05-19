import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { S3Client } from '@aws-sdk/client-s3';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadBucketCommand,
  PutObjectCommand,
} from '@aws-sdk/client-s3';

// ---------------------------------------------------------------------------
// Mock the presigner — we assert call shape, not the real signed URL output.
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
function makeClientStub() {
  return {
    send: vi.fn(),
  } as unknown as S3Client;
}

function makeAdapter(client: S3Client, overrides: Partial<typeof DEFAULT_CONFIG> = {}) {
  return new S3FileStorageAdapter({ client, ...DEFAULT_CONFIG, ...overrides });
}

// ---------------------------------------------------------------------------
// putObject
// ---------------------------------------------------------------------------

describe('putObject', () => {
  let client: S3Client;

  beforeEach(() => {
    client = makeClientStub();
    vi.mocked(client.send).mockResolvedValue({} as never);
  });

  it('sends a PutObjectCommand with Bucket, Key, Body, and ContentType', async () => {
    const adapter = makeAdapter(client);
    const body = Buffer.from('selfie-bytes');

    await adapter.putObject({ key: 'selfies/user-1/sub-1.jpg', body, contentType: 'image/jpeg' });

    expect(client.send).toHaveBeenCalledTimes(1);
    const [command] = vi.mocked(client.send).mock.calls[0]!;
    expect(command).toBeInstanceOf(PutObjectCommand);
    const cmd = command as PutObjectCommand;
    expect(cmd.input).toMatchObject({
      Bucket: BUCKET,
      Key: 'selfies/user-1/sub-1.jpg',
      Body: body,
      ContentType: 'image/jpeg',
    });
  });

  it('resolves to void on success', async () => {
    const adapter = makeAdapter(client);
    await expect(
      adapter.putObject({ key: 'selfies/user-1/sub-1.jpg', body: Buffer.from('x'), contentType: 'image/jpeg' }),
    ).resolves.toBeUndefined();
  });

  it('rethrows errors from S3', async () => {
    const adapter = makeAdapter(client);
    vi.mocked(client.send).mockRejectedValueOnce(new Error('AccessDenied'));
    await expect(
      adapter.putObject({ key: 'selfies/user-1/sub-1.jpg', body: Buffer.from('x'), contentType: 'image/jpeg' }),
    ).rejects.toThrow('AccessDenied');
  });
});

// ---------------------------------------------------------------------------
// deleteObject
// ---------------------------------------------------------------------------

describe('deleteObject', () => {
  let client: S3Client;

  beforeEach(() => {
    client = makeClientStub();
    vi.mocked(client.send).mockResolvedValue({} as never);
  });

  it('sends a DeleteObjectCommand with Bucket and Key', async () => {
    const adapter = makeAdapter(client);
    await adapter.deleteObject({ key: 'selfies/user-1/sub-1.jpg' });

    expect(client.send).toHaveBeenCalledTimes(1);
    const [command] = vi.mocked(client.send).mock.calls[0]!;
    expect(command).toBeInstanceOf(DeleteObjectCommand);
    const cmd = command as DeleteObjectCommand;
    expect(cmd.input).toMatchObject({ Bucket: BUCKET, Key: 'selfies/user-1/sub-1.jpg' });
  });

  it('resolves to void when S3 returns success', async () => {
    const adapter = makeAdapter(client);
    await expect(adapter.deleteObject({ key: 'selfies/user-1/sub-1.jpg' })).resolves.toBeUndefined();
  });

  it('swallows a NoSuchKey-shaped error (name === "NoSuchKey")', async () => {
    const adapter = makeAdapter(client);
    const notFound = Object.assign(new Error('NoSuchKey'), { name: 'NoSuchKey' });
    vi.mocked(client.send).mockRejectedValueOnce(notFound);
    await expect(adapter.deleteObject({ key: 'selfies/user-1/sub-1.jpg' })).resolves.toBeUndefined();
  });

  it('swallows a 404-shaped error ($metadata.httpStatusCode === 404)', async () => {
    const adapter = makeAdapter(client);
    const notFound = Object.assign(new Error('NotFound'), {
      $metadata: { httpStatusCode: 404 },
    });
    vi.mocked(client.send).mockRejectedValueOnce(notFound);
    await expect(adapter.deleteObject({ key: 'selfies/user-1/sub-1.jpg' })).resolves.toBeUndefined();
  });

  it('rethrows non-404 S3 errors', async () => {
    const adapter = makeAdapter(client);
    const accessDenied = Object.assign(new Error('AccessDenied'), {
      name: 'AccessDenied',
      $metadata: { httpStatusCode: 403 },
    });
    vi.mocked(client.send).mockRejectedValueOnce(accessDenied);
    await expect(adapter.deleteObject({ key: 'selfies/user-1/sub-1.jpg' })).rejects.toThrow('AccessDenied');
  });

  it('rethrows plain Error objects that are not not-found shaped', async () => {
    const adapter = makeAdapter(client);
    vi.mocked(client.send).mockRejectedValueOnce(new Error('InternalServerError'));
    await expect(adapter.deleteObject({ key: 'selfies/user-1/sub-1.jpg' })).rejects.toThrow('InternalServerError');
  });
});

// ---------------------------------------------------------------------------
// getSignedUrl
// ---------------------------------------------------------------------------

describe('getSignedUrl', () => {
  let client: S3Client;

  beforeEach(() => {
    client = makeClientStub();
    mockGetSignedUrl.mockClear();
    mockGetSignedUrl.mockResolvedValue('https://s3.example.com/signed-read-url');
  });

  it('calls the presigner with a GetObjectCommand, correct expiresIn, Bucket, and Key', async () => {
    const adapter = makeAdapter(client);
    const url = await adapter.getSignedUrl({ key: 'selfies/user-1/sub-1.jpg', expiresInSeconds: 900 });

    expect(mockGetSignedUrl).toHaveBeenCalledTimes(1);
    const firstCall = mockGetSignedUrl.mock.calls[0] as unknown as [
      S3Client,
      GetObjectCommand,
      { expiresIn: number },
    ];
    const [calledClient, calledCommand, calledOptions] = firstCall;
    expect(calledClient).toBe(client);
    expect(calledCommand).toBeInstanceOf(GetObjectCommand);
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
  let client: S3Client;

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
    const firstCall = mockGetSignedUrl.mock.calls[0] as unknown as [
      S3Client,
      PutObjectCommand,
      { expiresIn: number; signableHeaders?: Set<string> },
    ];
    const [calledClient, calledCommand, calledOptions] = firstCall;
    expect(calledClient).toBe(client);
    expect(calledCommand).toBeInstanceOf(PutObjectCommand);
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
  let client: S3Client;

  beforeEach(() => {
    client = makeClientStub();
    vi.mocked(client.send).mockResolvedValue({} as never);
  });

  it('sends a HeadBucketCommand with the configured Bucket', async () => {
    const adapter = makeAdapter(client);
    await adapter.verifyReachable();

    expect(client.send).toHaveBeenCalledTimes(1);
    const [command] = vi.mocked(client.send).mock.calls[0]!;
    expect(command).toBeInstanceOf(HeadBucketCommand);
    expect((command as HeadBucketCommand).input).toMatchObject({ Bucket: BUCKET });
  });

  it('resolves to void when HeadBucket succeeds', async () => {
    const adapter = makeAdapter(client);
    await expect(adapter.verifyReachable()).resolves.toBeUndefined();
  });

  it('throws when client rejects — error message includes bucket name', async () => {
    const adapter = makeAdapter(client);
    vi.mocked(client.send).mockRejectedValueOnce(new Error('NoSuchBucket'));

    await expect(adapter.verifyReachable()).rejects.toThrow(BUCKET);
  });

  it('wraps the original error message in the thrown error', async () => {
    const adapter = makeAdapter(client);
    vi.mocked(client.send).mockRejectedValueOnce(new Error('network timeout'));

    await expect(adapter.verifyReachable()).rejects.toThrow('network timeout');
  });

  it('handles non-Error throws — converts to string in the message', async () => {
    const adapter = makeAdapter(client);
    vi.mocked(client.send).mockRejectedValueOnce('connection refused');

    await expect(adapter.verifyReachable()).rejects.toThrow('connection refused');
  });
});

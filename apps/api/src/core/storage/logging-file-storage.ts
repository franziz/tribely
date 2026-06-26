import { logger } from '../middleware/logger.js';
import type { FileStorage } from './file-storage.port.js';

export class LoggingFileStorage implements FileStorage {
  // No `async` — these are synchronous logger calls. Wrapping with
  // Promise.resolve honors the port contract without `require-await`.
  putObject(input: { key: string; body: Buffer; contentType: string }): Promise<void> {
    logger.info(
      { key: input.key, contentType: input.contentType, sizeBytes: input.body.length },
      'storage.putObject (DEV — not actually stored)',
    );
    return Promise.resolve();
  }

  deleteObject(input: { key: string }): Promise<void> {
    logger.info({ key: input.key }, 'storage.deleteObject (DEV — not actually stored)');
    return Promise.resolve();
  }

  getSignedUrl(input: { key: string; expiresInSeconds: number }): Promise<string> {
    logger.info(
      { key: input.key, expiresInSeconds: input.expiresInSeconds },
      'storage.getSignedUrl (DEV — fake URL)',
    );
    return Promise.resolve(
      `https://storage.local/${input.key}?expires=${String(input.expiresInSeconds)}`,
    );
  }

  getSignedUploadUrl(input: {
    key: string;
    contentType: string;
    expiresInSeconds: number;
  }): Promise<string> {
    logger.info(
      { key: input.key, contentType: input.contentType, expiresInSeconds: input.expiresInSeconds },
      'storage.getSignedUploadUrl (DEV — fake URL)',
    );
    return Promise.resolve(
      `https://storage.local/${input.key}?upload=1&expires=${String(input.expiresInSeconds)}`,
    );
  }

  getObjectSize(input: { key: string }): Promise<number> {
    logger.info({ key: input.key }, 'storage.getObjectSize (DEV — returns 1 byte)');
    // Always report a tiny fake size so the dev path "just works" regardless of
    // whether the key was ever written. The logging transport is intentionally
    // not a real object store, so a literal size check is meaningless here.
    return Promise.resolve(1);
  }
}

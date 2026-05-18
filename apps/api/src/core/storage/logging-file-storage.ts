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
}

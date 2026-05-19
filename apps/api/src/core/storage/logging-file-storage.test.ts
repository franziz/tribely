import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { logger } from '../middleware/logger.js';
import { LoggingFileStorage } from './logging-file-storage.js';

describe('LoggingFileStorage', () => {
  let infoSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    infoSpy = vi.spyOn(logger, 'info').mockImplementation(() => undefined);
  });

  afterEach(() => {
    infoSpy.mockRestore();
  });

  describe('putObject', () => {
    it('resolves without throwing', async () => {
      const storage = new LoggingFileStorage();
      await expect(
        storage.putObject({
          key: 'selfies/user-1/sub-1.jpg',
          body: Buffer.from('data'),
          contentType: 'image/jpeg',
        }),
      ).resolves.toBeUndefined();
    });

    it('logs key, contentType, and sizeBytes at info level', async () => {
      const storage = new LoggingFileStorage();
      const body = Buffer.from('hello');
      await storage.putObject({ key: 'selfies/user-1/sub-1.jpg', body, contentType: 'image/jpeg' });

      expect(infoSpy).toHaveBeenCalledTimes(1);
      expect(infoSpy).toHaveBeenCalledWith(
        { key: 'selfies/user-1/sub-1.jpg', contentType: 'image/jpeg', sizeBytes: body.length },
        expect.stringContaining('storage.putObject'),
      );
    });
  });

  describe('deleteObject', () => {
    it('resolves without throwing', async () => {
      const storage = new LoggingFileStorage();
      await expect(
        storage.deleteObject({ key: 'selfies/user-1/sub-1.jpg' }),
      ).resolves.toBeUndefined();
    });

    it('logs key at info level', async () => {
      const storage = new LoggingFileStorage();
      await storage.deleteObject({ key: 'selfies/user-1/sub-1.jpg' });

      expect(infoSpy).toHaveBeenCalledTimes(1);
      expect(infoSpy).toHaveBeenCalledWith(
        { key: 'selfies/user-1/sub-1.jpg' },
        expect.stringContaining('storage.deleteObject'),
      );
    });
  });

  describe('getSignedUrl', () => {
    it('returns the deterministic fake URL pattern', async () => {
      const storage = new LoggingFileStorage();
      const url = await storage.getSignedUrl({
        key: 'selfies/user-1/sub-1.jpg',
        expiresInSeconds: 3600,
      });

      expect(url).toMatch(/^https:\/\/storage\.local\/.+\?expires=\d+$/);
      expect(url).toBe('https://storage.local/selfies/user-1/sub-1.jpg?expires=3600');
    });

    it('logs key and expiresInSeconds at info level', async () => {
      const storage = new LoggingFileStorage();
      await storage.getSignedUrl({ key: 'selfies/user-1/sub-1.jpg', expiresInSeconds: 3600 });

      expect(infoSpy).toHaveBeenCalledTimes(1);
      expect(infoSpy).toHaveBeenCalledWith(
        { key: 'selfies/user-1/sub-1.jpg', expiresInSeconds: 3600 },
        expect.stringContaining('storage.getSignedUrl'),
      );
    });

    it('resolves without throwing', async () => {
      const storage = new LoggingFileStorage();
      await expect(
        storage.getSignedUrl({ key: 'selfies/user-1/sub-1.jpg', expiresInSeconds: 900 }),
      ).resolves.toBeDefined();
    });
  });

  describe('getSignedUploadUrl', () => {
    it('returns the deterministic fake URL pattern', async () => {
      const storage = new LoggingFileStorage();
      const url = await storage.getSignedUploadUrl({
        key: 'selfies/user-1/sub-1.jpg',
        contentType: 'image/jpeg',
        expiresInSeconds: 3600,
      });

      expect(url).toMatch(/^https:\/\/storage\.local\/.+\?upload=1&expires=\d+$/);
      expect(url).toBe(
        'https://storage.local/selfies/user-1/sub-1.jpg?upload=1&expires=3600',
      );
    });

    it('logs key, contentType, and expiresInSeconds at info level', async () => {
      const storage = new LoggingFileStorage();
      await storage.getSignedUploadUrl({
        key: 'selfies/user-1/sub-1.jpg',
        contentType: 'image/jpeg',
        expiresInSeconds: 3600,
      });

      expect(infoSpy).toHaveBeenCalledTimes(1);
      expect(infoSpy).toHaveBeenCalledWith(
        { key: 'selfies/user-1/sub-1.jpg', contentType: 'image/jpeg', expiresInSeconds: 3600 },
        expect.stringContaining('storage.getSignedUploadUrl'),
      );
    });

    it('resolves without throwing', async () => {
      const storage = new LoggingFileStorage();
      await expect(
        storage.getSignedUploadUrl({
          key: 'selfies/user-1/sub-1.jpg',
          contentType: 'image/png',
          expiresInSeconds: 900,
        }),
      ).resolves.toBeDefined();
    });
  });
});

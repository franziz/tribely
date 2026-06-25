import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import type { FileStorage } from '@/core/storage/file-storage.port.js';
import { RequestCoverPhotoUploadUseCase } from './request-cover-photo-upload.usecase.js';

class FakeFileStorage implements FileStorage {
  getSignedUploadUrl(input: {
    key: string;
    contentType: string;
    expiresInSeconds: number;
  }): Promise<string> {
    return Promise.resolve(`https://example.com/upload/${input.key}`);
  }

  getSignedUrl(input: { key: string; expiresInSeconds: number }): Promise<string> {
    return Promise.resolve(`https://example.com/read/${input.key}`);
  }

  putObject(_input: { key: string; body: Buffer; contentType: string }): Promise<void> {
    return Promise.resolve();
  }

  deleteObject(_input: { key: string }): Promise<void> {
    return Promise.resolve();
  }
}

const buildSut = () => {
  const fileStorage = new FakeFileStorage();
  const useCase = new RequestCoverPhotoUploadUseCase(fileStorage);
  return { fileStorage, useCase };
};

describe('RequestCoverPhotoUploadUseCase', () => {
  describe('mime type validation', () => {
    it('accepts image/jpeg and maps extension to .jpg', async () => {
      const { useCase } = buildSut();
      const result = await useCase.execute({
        hostUserId: 'user_abc',
        contentType: 'image/jpeg',
      });

      expect(result.storageKey).toMatch(/^events\/user_abc\/.+\.jpg$/);
      expect(result.uploadUrl).toContain(result.storageKey);
    });

    it('accepts image/png and maps extension to .png', async () => {
      const { useCase } = buildSut();
      const result = await useCase.execute({
        hostUserId: 'user_abc',
        contentType: 'image/png',
      });

      expect(result.storageKey).toMatch(/^events\/user_abc\/.+\.png$/);
    });

    it('accepts image/webp and maps extension to .webp', async () => {
      const { useCase } = buildSut();
      const result = await useCase.execute({
        hostUserId: 'user_abc',
        contentType: 'image/webp',
      });

      expect(result.storageKey).toMatch(/^events\/user_abc\/.+\.webp$/);
    });

    it('rejects image/gif with 400 VALIDATION_ERROR', async () => {
      const { useCase } = buildSut();
      const err = await useCase
        .execute({ hostUserId: 'user_abc', contentType: 'image/gif' })
        .catch((e: unknown) => e);

      expect(err).toBeInstanceOf(AppError);
      const appErr = err as AppError;
      expect(appErr.status).toBe(400);
      expect(appErr.code).toBe('VALIDATION_ERROR');
    });

    it('rejects empty contentType with 400 VALIDATION_ERROR', async () => {
      const { useCase } = buildSut();
      const err = await useCase
        .execute({ hostUserId: 'user_abc', contentType: '' })
        .catch((e: unknown) => e);

      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).status).toBe(400);
    });

    it('rejects application/pdf with 400 VALIDATION_ERROR', async () => {
      const { useCase } = buildSut();
      const err = await useCase
        .execute({ hostUserId: 'user_abc', contentType: 'application/pdf' })
        .catch((e: unknown) => e);

      expect(err).toBeInstanceOf(AppError);
      expect((err as AppError).status).toBe(400);
    });
  });

  describe('key format', () => {
    it('produces a unique key per call (distinct cuid2 image IDs)', async () => {
      const { useCase } = buildSut();
      const [r1, r2] = await Promise.all([
        useCase.execute({ hostUserId: 'user_abc', contentType: 'image/jpeg' }),
        useCase.execute({ hostUserId: 'user_abc', contentType: 'image/jpeg' }),
      ]);

      expect(r1.storageKey).not.toBe(r2.storageKey);
    });

    it('scopes the key to the provided hostUserId prefix', async () => {
      const { useCase } = buildSut();
      const result = await useCase.execute({
        hostUserId: 'host_xyz',
        contentType: 'image/webp',
      });

      expect(result.storageKey.startsWith('events/host_xyz/')).toBe(true);
    });
  });

  describe('presigned URL', () => {
    it('returns the upload URL from FileStorage.getSignedUploadUrl', async () => {
      const { useCase } = buildSut();
      const result = await useCase.execute({
        hostUserId: 'user_abc',
        contentType: 'image/jpeg',
      });

      // FakeFileStorage returns https://example.com/upload/<key>
      expect(result.uploadUrl).toBe(`https://example.com/upload/${result.storageKey}`);
    });
  });
});

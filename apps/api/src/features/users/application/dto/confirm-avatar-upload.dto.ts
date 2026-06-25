import type { User } from '../../domain/entities/user.js';

export type ConfirmAvatarUploadInput = {
  userId: string;
  storageKey: string;
};

export type ConfirmAvatarUploadResult = {
  user: User;
};

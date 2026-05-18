import type { User } from '../../domain/entities/user.js';

export type GetUserResult = {
  user: User;
  isVerified: boolean;
};

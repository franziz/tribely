import type { User as PrismaUser } from '@prisma/client';
import type { User } from '../../domain/entities/user.js';

export type UserModel = PrismaUser;

export const toUserEntity = (model: UserModel): User => ({
  id: model.id,
  email: model.email,
  displayName: model.displayName,
  createdAt: model.createdAt,
  updatedAt: model.updatedAt,
});

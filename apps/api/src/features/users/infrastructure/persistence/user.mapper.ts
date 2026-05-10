import type { User as UserRow } from '@prisma/client';
import { User } from '../../domain/entities/user.js';
import { DisplayName } from '../../domain/value-objects/display-name.js';
import { Email } from '../../domain/value-objects/email.js';

export const toUser = (row: UserRow): User =>
  User.rehydrate({
    id: row.id,
    email: Email.create(row.email),
    displayName: DisplayName.create(row.displayName),
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    emailVerifiedAt: row.emailVerifiedAt,
  });

export const toRow = (user: User): UserRow => ({
  id: user.id,
  email: user.email.value,
  displayName: user.displayName.value,
  createdAt: user.createdAt,
  updatedAt: user.updatedAt,
  emailVerifiedAt: user.emailVerifiedAt,
});

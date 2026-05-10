import type { PasswordResetToken as PasswordResetTokenRow } from '@prisma/client';
import { PasswordResetToken } from '../../domain/entities/password-reset-token.js';

export const toPasswordResetToken = (row: PasswordResetTokenRow): PasswordResetToken =>
  PasswordResetToken.rehydrate({
    id: row.id,
    userId: row.userId,
    codeHash: row.codeHash,
    issuedAt: row.issuedAt,
    expiresAt: row.expiresAt,
    consumedAt: row.consumedAt,
    attempts: row.attempts,
    invalidated: row.invalidated,
  });

export const toRow = (token: PasswordResetToken): PasswordResetTokenRow => ({
  id: token.id,
  userId: token.userId,
  codeHash: token.codeHash,
  issuedAt: token.issuedAt,
  expiresAt: token.expiresAt,
  consumedAt: token.consumedAt,
  attempts: token.attempts,
  invalidated: token.invalidated,
});

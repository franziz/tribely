import type { EmailVerificationToken as EmailVerificationTokenRow } from '@prisma/client';
import { EmailVerificationToken } from '../../domain/entities/email-verification-token.js';

export const toEmailVerificationToken = (row: EmailVerificationTokenRow): EmailVerificationToken =>
  EmailVerificationToken.rehydrate({
    id: row.id,
    userId: row.userId,
    codeHash: row.codeHash,
    issuedAt: row.issuedAt,
    expiresAt: row.expiresAt,
    consumedAt: row.consumedAt,
    attempts: row.attempts,
    invalidated: row.invalidated,
  });

export const toRow = (token: EmailVerificationToken): EmailVerificationTokenRow => ({
  id: token.id,
  userId: token.userId,
  codeHash: token.codeHash,
  issuedAt: token.issuedAt,
  expiresAt: token.expiresAt,
  consumedAt: token.consumedAt,
  attempts: token.attempts,
  invalidated: token.invalidated,
});

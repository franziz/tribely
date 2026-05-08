import type { Credential as CredentialRow } from '@prisma/client';
import { Credential } from '../../domain/entities/credential.js';
import { HashedPassword } from '../../domain/value-objects/hashed-password.js';

export const toCredential = (row: CredentialRow): Credential =>
  Credential.rehydrate({
    userId: row.userId,
    passwordHash: HashedPassword.fromHash(row.passwordHash),
    passwordSetAt: row.passwordSetAt,
    lastSignedInAt: row.lastSignedInAt,
  });

export const toRow = (credential: Credential): CredentialRow => ({
  userId: credential.userId,
  passwordHash: credential.passwordHash.value,
  passwordSetAt: credential.passwordSetAt,
  lastSignedInAt: credential.lastSignedInAt,
});

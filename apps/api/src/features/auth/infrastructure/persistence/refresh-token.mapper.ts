import type { RefreshToken as RefreshTokenRow } from '@prisma/client';
import { RefreshToken } from '../../domain/entities/refresh-token.js';
import type { RefreshTokenRevokedReason } from '../../domain/events/refresh-token-revoked.event.js';

const isRevokedReason = (s: string | null): s is RefreshTokenRevokedReason =>
  s === 'rotated' || s === 'signed_out' || s === 'reuse_detected' || s === 'sign_out_all';

export const toRefreshToken = (row: RefreshTokenRow): RefreshToken =>
  RefreshToken.rehydrate({
    id: row.id,
    userId: row.userId,
    tokenHash: row.tokenHash,
    issuedAt: row.issuedAt,
    expiresAt: row.expiresAt,
    revokedAt: row.revokedAt,
    revokedReason: isRevokedReason(row.revokedReason) ? row.revokedReason : null,
    lastUsedAt: row.lastUsedAt,
    rotatedToId: row.rotatedToId,
    deviceLabel: row.deviceLabel,
  });

export const toRow = (token: RefreshToken): RefreshTokenRow => ({
  id: token.id,
  userId: token.userId,
  tokenHash: token.tokenHash,
  issuedAt: token.issuedAt,
  expiresAt: token.expiresAt,
  revokedAt: token.revokedAt,
  revokedReason: token.revokedReason,
  lastUsedAt: token.lastUsedAt,
  rotatedToId: token.rotatedToId,
  deviceLabel: token.deviceLabel,
});

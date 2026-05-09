import type { DomainEvent } from '@/core/events/domain-event.js';

export const REFRESH_TOKEN_REVOKED = 'auth.refreshTokenRevoked' as const;

export type RefreshTokenRevokedReason =
  | 'rotated'
  | 'signed_out'
  | 'reuse_detected'
  | 'sign_out_all';

export interface RefreshTokenRevokedPayload {
  refreshTokenId: string;
  userId: string;
  reason: RefreshTokenRevokedReason;
  revokedAt: string;
}

export type RefreshTokenRevokedEvent = DomainEvent<RefreshTokenRevokedPayload> & {
  type: typeof REFRESH_TOKEN_REVOKED;
};

export const refreshTokenRevoked = (
  payload: RefreshTokenRevokedPayload,
): RefreshTokenRevokedEvent => ({
  type: REFRESH_TOKEN_REVOKED,
  aggregateType: 'RefreshToken',
  aggregateId: payload.refreshTokenId,
  payload,
  version: 1,
});

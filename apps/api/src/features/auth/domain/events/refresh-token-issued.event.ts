import type { DomainEvent } from '@/core/events/domain-event.js';

export const REFRESH_TOKEN_ISSUED = 'auth.refreshTokenIssued' as const;

export interface RefreshTokenIssuedPayload {
  refreshTokenId: string;
  userId: string;
  issuedAt: string;
  expiresAt: string;
  deviceLabel: string | null;
}

export type RefreshTokenIssuedEvent = DomainEvent<RefreshTokenIssuedPayload> & {
  type: typeof REFRESH_TOKEN_ISSUED;
};

export const refreshTokenIssued = (
  payload: RefreshTokenIssuedPayload,
): RefreshTokenIssuedEvent => ({
  type: REFRESH_TOKEN_ISSUED,
  aggregateType: 'RefreshToken',
  aggregateId: payload.refreshTokenId,
  payload,
  version: 1,
});

import type { DomainEvent } from '@/core/events/domain-event.js';

export const REFRESH_TOKEN_ROTATED = 'auth.refreshTokenRotated' as const;

export interface RefreshTokenRotatedPayload {
  refreshTokenId: string;
  userId: string;
  rotatedToId: string;
  rotatedAt: string;
}

export type RefreshTokenRotatedEvent = DomainEvent<RefreshTokenRotatedPayload> & {
  type: typeof REFRESH_TOKEN_ROTATED;
};

export const refreshTokenRotated = (
  payload: RefreshTokenRotatedPayload,
): RefreshTokenRotatedEvent => ({
  type: REFRESH_TOKEN_ROTATED,
  aggregateType: 'RefreshToken',
  aggregateId: payload.refreshTokenId,
  payload,
  version: 1,
});

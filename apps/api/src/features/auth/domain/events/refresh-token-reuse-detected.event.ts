import type { DomainEvent } from '@/core/events/domain-event.js';

/**
 * Critical security signal: a refresh token that was previously revoked
 * (typically by rotation) was presented again. This is a strong indicator
 * the token has leaked. The application response is to revoke ALL of the
 * user's refresh tokens, forcing every device to re-authenticate.
 *
 * Subscribers might also: alert security ops, lock the account, send the
 * user an email about suspicious activity. Those are separate concerns.
 */

export const REFRESH_TOKEN_REUSE_DETECTED = 'auth.refreshTokenReuseDetected' as const;

export interface RefreshTokenReuseDetectedPayload {
  refreshTokenId: string;
  userId: string;
  detectedAt: string;
}

export type RefreshTokenReuseDetectedEvent = DomainEvent<RefreshTokenReuseDetectedPayload> & {
  type: typeof REFRESH_TOKEN_REUSE_DETECTED;
};

export const refreshTokenReuseDetected = (
  payload: RefreshTokenReuseDetectedPayload,
): RefreshTokenReuseDetectedEvent => ({
  type: REFRESH_TOKEN_REUSE_DETECTED,
  aggregateType: 'RefreshToken',
  aggregateId: payload.refreshTokenId,
  payload,
  version: 1,
});

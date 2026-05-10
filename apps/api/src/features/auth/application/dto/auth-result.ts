import type { User } from '@/features/users/domain/entities/user.js';
import type { AccessToken } from '../../domain/ports/access-token-issuer.port.js';

/**
 * Shared result shape for sign-up / sign-in / refresh — the use case returns
 * the user, the access token (JWT, expires soon), and the refresh token
 * plaintext (shown to the client once; only its hash is persisted).
 */
export interface IssuedAuthSession {
  user: User;
  accessToken: AccessToken;
  refreshTokenPlaintext: string;
  refreshTokenExpiresAt: Date;
}

/**
 * Result of `SignOutAllUseCase.execute(...)` — how many active refresh tokens
 * the user had that we just revoked. Trivial today, but a named DTO so the
 * use case signature stays explicit + future fields (e.g. `revokedAt`,
 * `affectedDeviceLabels`) extend without churning every call site.
 */
export interface SignOutAllResult {
  revokedCount: number;
}

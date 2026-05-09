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

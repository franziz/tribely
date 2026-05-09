import { SignJWT, jwtVerify } from 'jose';
import { env } from '@/core/config/env.js';
import { AppError } from '@/core/errors/app-error.js';
import type {
  AccessToken,
  AccessTokenIssuer,
  TokenSubject,
} from '../../domain/ports/access-token-issuer.port.js';

const secret = new TextEncoder().encode(env.JWT_SECRET);

const parseDurationSeconds = (value: string): number => {
  const match = /^(\d+)([smhd])$/.exec(value);
  if (!match) throw new Error(`Invalid TTL: ${value}`);
  const n = Number(match[1]);
  switch (match[2]) {
    case 's':
      return n;
    case 'm':
      return n * 60;
    case 'h':
      return n * 60 * 60;
    case 'd':
      return n * 60 * 60 * 24;
    default:
      throw new Error(`Invalid TTL unit: ${match[2]}`);
  }
};

/**
 * JWT-backed access token issuer. Access tokens are short-lived (default 15m)
 * stateless tokens — verification is a signature check, no DB roundtrip.
 *
 * Refresh tokens are NOT JWTs; they're opaque and stored hashed (see
 * Sha256RefreshTokenHasher).
 */
export class JwtAccessTokenIssuer implements AccessTokenIssuer {
  async issue(subject: TokenSubject): Promise<AccessToken> {
    const seconds = parseDurationSeconds(env.JWT_ACCESS_TTL);
    const value = await new SignJWT({ email: subject.email })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(subject.userId)
      .setIssuedAt()
      .setExpirationTime(`${seconds}s`)
      .sign(secret);
    return {
      value,
      expiresAt: new Date(Date.now() + seconds * 1000),
    };
  }

  async verify(token: string): Promise<TokenSubject> {
    try {
      const { payload } = await jwtVerify(token, secret);
      if (typeof payload.sub !== 'string' || typeof payload.email !== 'string') {
        throw AppError.unauthorized('Invalid token payload');
      }
      return { userId: payload.sub, email: payload.email };
    } catch {
      throw AppError.unauthorized('Invalid or expired token');
    }
  }
}

import { SignJWT, jwtVerify } from 'jose';
import { env } from '@/core/config/env.js';
import { AppError } from '@/core/errors/app-error.js';
import type {
  AuthTokens,
  TokenIssuer,
  TokenSubject,
} from '../../domain/ports/token-issuer.port.js';

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

export class JwtTokenIssuer implements TokenIssuer {
  async issue(subject: TokenSubject): Promise<AuthTokens> {
    const accessSec = parseDurationSeconds(env.JWT_ACCESS_TTL);
    const refreshSec = parseDurationSeconds(env.JWT_REFRESH_TTL);

    const accessToken = await new SignJWT({ email: subject.email })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(subject.userId)
      .setIssuedAt()
      .setExpirationTime(`${accessSec}s`)
      .sign(secret);

    const refreshToken = await new SignJWT({ type: 'refresh' })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(subject.userId)
      .setIssuedAt()
      .setExpirationTime(`${refreshSec}s`)
      .sign(secret);

    return {
      accessToken,
      refreshToken,
      accessTokenExpiresAt: new Date(Date.now() + accessSec * 1000),
    };
  }

  async verifyAccess(token: string): Promise<TokenSubject> {
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

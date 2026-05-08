import { SignJWT, jwtVerify } from 'jose';
import { env } from '@/core/config/env.js';
import { AppError } from '@/core/errors/app-error.js';
import type {
  AuthTokens,
  TokenPayload,
  TokenService,
} from '../../domain/services/token.service.js';

const secret = new TextEncoder().encode(env.JWT_SECRET);

const parseDurationToSeconds = (value: string): number => {
  const match = /^(\d+)([smhd])$/.exec(value);
  if (!match) throw new Error(`Invalid TTL: ${value}`);
  const n = Number(match[1]);
  const unit = match[2];
  switch (unit) {
    case 's':
      return n;
    case 'm':
      return n * 60;
    case 'h':
      return n * 60 * 60;
    case 'd':
      return n * 60 * 60 * 24;
    default:
      throw new Error(`Invalid TTL unit: ${unit}`);
  }
};

export class JwtTokenService implements TokenService {
  async issueTokens(payload: TokenPayload): Promise<AuthTokens> {
    const accessSeconds = parseDurationToSeconds(env.JWT_ACCESS_TTL);
    const refreshSeconds = parseDurationToSeconds(env.JWT_REFRESH_TTL);

    const accessToken = await new SignJWT({ email: payload.email })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(payload.sub)
      .setIssuedAt()
      .setExpirationTime(`${accessSeconds}s`)
      .sign(secret);

    const refreshToken = await new SignJWT({ type: 'refresh' })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(payload.sub)
      .setIssuedAt()
      .setExpirationTime(`${refreshSeconds}s`)
      .sign(secret);

    return {
      accessToken,
      refreshToken,
      accessTokenExpiresAt: new Date(Date.now() + accessSeconds * 1000),
    };
  }

  async verifyAccessToken(token: string): Promise<TokenPayload> {
    try {
      const { payload } = await jwtVerify(token, secret);
      if (typeof payload.sub !== 'string' || typeof payload.email !== 'string') {
        throw AppError.unauthorized('Invalid token payload');
      }
      return { sub: payload.sub, email: payload.email };
    } catch {
      throw AppError.unauthorized('Invalid or expired token');
    }
  }
}

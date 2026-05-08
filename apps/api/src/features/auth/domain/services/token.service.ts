export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: Date;
}

export interface TokenPayload {
  sub: string;
  email: string;
}

export interface TokenService {
  issueTokens(payload: TokenPayload): Promise<AuthTokens>;
  verifyAccessToken(token: string): Promise<TokenPayload>;
}

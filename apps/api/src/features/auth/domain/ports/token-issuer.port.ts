/**
 * Outbound port: issues and verifies authentication tokens.
 * Concrete impl decides JWT / Paseto / sessions / etc.
 */
export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: Date;
}

export interface TokenSubject {
  userId: string;
  email: string;
}

export interface TokenIssuer {
  issue(subject: TokenSubject): Promise<AuthTokens>;
  verifyAccess(token: string): Promise<TokenSubject>;
}

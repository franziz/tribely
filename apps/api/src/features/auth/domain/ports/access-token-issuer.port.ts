/**
 * Outbound port: issue and verify short-lived access tokens.
 *
 * Concrete impl is JWT (`JwtAccessTokenIssuer`), but the domain doesn't
 * care — could be Paseto, opaque tokens with a verification endpoint, etc.
 */

export interface AccessToken {
  value: string;
  expiresAt: Date;
}

export interface TokenSubject {
  userId: string;
  email: string;
}

export interface AccessTokenIssuer {
  issue(subject: TokenSubject): Promise<AccessToken>;
  verify(token: string): Promise<TokenSubject>;
}

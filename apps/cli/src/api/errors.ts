/**
 * Typed error classes for the CLI API client.
 *
 * - ApiError       — server responded with a non-2xx status and an error envelope.
 * - NetworkError   — fetch rejected (ENOTFOUND, ECONNREFUSED, etc.).
 * - SessionExpiredError — refresh token is revoked or expired; operator must re-login.
 * - NotLoggedInError   — no session on disk; operator must login first.
 */

export class ApiError extends Error {
  readonly status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

export class NetworkError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NetworkError';
  }
}

export class SessionExpiredError extends Error {
  constructor(message = "Session expired, please run `tribely auth login` again") {
    super(message);
    this.name = 'SessionExpiredError';
  }
}

export class NotLoggedInError extends Error {
  constructor(message = 'Not logged in — run `tribely auth login` first') {
    super(message);
    this.name = 'NotLoggedInError';
  }
}

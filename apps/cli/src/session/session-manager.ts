/**
 * Silent access-token refresh manager.
 *
 * The API access token is short-lived (default 15 min). This module ensures
 * that subsequent CLI invocations always get a valid token without user
 * interaction — it silently refreshes when the access token is within 30s of
 * expiry or already expired.
 *
 * Flow:
 *  1. Load session from disk.
 *  2. If no session → throw NotLoggedInError.
 *  3. If access token expiry ≤ now + 30s → call refresh endpoint, save rotated
 *     session, return new access token.
 *  4. If refresh returns 401 → throw SessionExpiredError (operator must re-login).
 *  5. Otherwise → return stored access token.
 */

import * as apiClient from '../api/api-client.js';
import { ApiError, NotLoggedInError, SessionExpiredError } from '../api/errors.js';
import { loadSession, saveSession } from './session-store.js';

/** Tokens expiring within this window (ms) are treated as already expired. */
const EXPIRY_BUFFER_MS = 30_000;

/**
 * Return a valid access token, refreshing silently if needed.
 *
 * Throws:
 * - NotLoggedInError   — no session on disk.
 * - SessionExpiredError — refresh token is revoked or expired.
 * - ApiError / NetworkError — unexpected API failure (caller should surface it).
 */
export async function getValidAccessToken(): Promise<string> {
  const session = loadSession();

  if (session === null) {
    throw new NotLoggedInError();
  }

  const expiresAt = new Date(session.accessToken.expiresAt).getTime();
  const now = Date.now();
  const isNearExpiry = expiresAt - now <= EXPIRY_BUFFER_MS;

  if (!isNearExpiry) {
    return session.accessToken.value;
  }

  // Access token is expired or about to expire — silently refresh.
  try {
    const rotated = await apiClient.refresh(session.refreshToken.value);
    saveSession(rotated);
    return rotated.accessToken.value;
  } catch (err) {
    if (err instanceof ApiError && err.status === 401) {
      throw new SessionExpiredError();
    }
    // Re-throw ApiError with non-401 status or NetworkError — let the caller handle.
    throw err;
  }
}

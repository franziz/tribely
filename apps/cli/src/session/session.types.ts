/**
 * Persisted on-disk session shape — written to `~/.tribely/config.json`.
 * Mirrors the API's AuthResponse with ISO-string timestamps.
 */
export interface StoredSession {
  accessToken: { value: string; expiresAt: string };
  refreshToken: { value: string; expiresAt: string };
  user: { id: string; email: string; displayName: string };
}

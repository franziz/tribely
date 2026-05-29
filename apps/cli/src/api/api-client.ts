/**
 * Thin wrapper over Node 22 native fetch for the Tribely API.
 *
 * Responsibilities:
 * - Resolve the base URL from env (AC6).
 * - Map auth endpoints to typed results.
 * - Convert non-2xx responses to typed ApiError (clean message, no raw dumps).
 * - Convert fetch rejections (network-level) to typed NetworkError.
 */

import type { StoredSession } from '../session/session.types.js';
import { ApiError, NetworkError } from './errors.js';

// ---------------------------------------------------------------------------
// Local DTO — mirrors apps/api AuthUserDto shape (auth.schemas.ts).
// Cross-workspace Zod import is out of scope; plain TS type suffices.
// ---------------------------------------------------------------------------

export interface AuthUserDto {
  id: string;
  email: string;
  displayName: string;
  emailVerifiedAt: string | null;
  bio: string | null;
  avatarUrl: string | null;
  languages: string[];
  interests: string[];
  currentCity: string | null;
  travelerType: 'local' | 'traveling' | 'expat' | null;
  createdAt: string;
  updatedAt: string;
}

// The raw shape returned by POST /auth/sign-in and POST /auth/refresh.
interface AuthApiResponse {
  user: AuthUserDto;
  accessToken: { value: string; expiresAt: string };
  refreshToken: { value: string; expiresAt: string };
}

// The uniform error envelope used by every non-2xx response.
interface ApiErrorEnvelope {
  error: { code: string; message: string; details?: unknown };
}

// ---------------------------------------------------------------------------
// Base URL
// ---------------------------------------------------------------------------

export function resolveBaseUrl(): string {
  return process.env.API_BASE_URL ?? 'http://localhost:3000';
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Wraps fetch so that network-level rejections surface as NetworkError.
 * Any 2xx/non-2xx HTTP response is returned as-is for the caller to inspect.
 */
async function safeFetch(input: string, init?: RequestInit): Promise<Response> {
  try {
    return await fetch(input, init);
  } catch (cause) {
    // fetch rejects on ENOTFOUND, ECONNREFUSED, etc.
    const hint =
      cause instanceof Error && cause.message ? `: ${cause.message}` : '';
    throw new NetworkError(
      `Unable to reach the Tribely API at ${resolveBaseUrl()}${hint}. Check your connection or API_BASE_URL.`,
    );
  }
}

/**
 * Reads a non-2xx response and throws an ApiError with a clean message.
 * Falls back to a generic message when the body doesn't match the error envelope.
 */
async function throwFromResponse(response: Response): Promise<never> {
  let message = `Request failed with status ${response.status.toString()}`;
  try {
    // Cast to unknown first so ESLint's no-unnecessary-condition can narrow
    // correctly without redundancy complaints.
    const body: unknown = await response.json();
    if (isApiErrorEnvelope(body)) {
      message = body.error.message;
    }
  } catch {
    // Body is not JSON — keep the generic message.
  }
  throw new ApiError(message, response.status);
}

function isApiErrorEnvelope(v: unknown): v is ApiErrorEnvelope {
  return (
    v !== null &&
    typeof v === 'object' &&
    'error' in v &&
    (v as Record<string, unknown>).error !== null &&
    typeof (v as Record<string, unknown>).error === 'object' &&
    'message' in (v as { error: Record<string, unknown> }).error &&
    typeof (v as { error: Record<string, unknown> }).error.message === 'string'
  );
}

/**
 * Map an AuthApiResponse to the on-disk StoredSession shape.
 */
function toStoredSession(body: AuthApiResponse): StoredSession {
  return {
    user: {
      id: body.user.id,
      email: body.user.email,
      displayName: body.user.displayName,
    },
    accessToken: {
      value: body.accessToken.value,
      expiresAt: body.accessToken.expiresAt,
    },
    refreshToken: {
      value: body.refreshToken.value,
      expiresAt: body.refreshToken.expiresAt,
    },
  };
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Authenticate with email + password. Maps the response to a StoredSession.
 *
 * Throws:
 * - ApiError (status 401) when credentials are invalid.
 * - NetworkError when the API is unreachable.
 *
 * Deliberately does NOT call saveSession — the caller (Brief 3 command handler)
 * decides when to persist (AC8b: login failure must not clobber prior session).
 */
export async function login(email: string, password: string): Promise<StoredSession> {
  const url = `${resolveBaseUrl()}/auth/sign-in`;
  const response = await safeFetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, deviceLabel: 'tribely-cli' }),
  });

  if (!response.ok) {
    await throwFromResponse(response);
  }

  const body = (await response.json()) as AuthApiResponse;
  return toStoredSession(body);
}

/**
 * Fetch the currently authenticated user profile.
 *
 * Throws:
 * - ApiError (status 401) when the token is invalid or expired.
 * - NetworkError when the API is unreachable.
 */
export async function whoami(accessTokenValue: string): Promise<AuthUserDto> {
  const url = `${resolveBaseUrl()}/auth/me`;
  const response = await safeFetch(url, {
    method: 'GET',
    headers: { Authorization: `Bearer ${accessTokenValue}` },
  });

  if (!response.ok) {
    await throwFromResponse(response);
  }

  return (await response.json()) as AuthUserDto;
}

/**
 * Exchange a refresh token for a new rotated token pair.
 *
 * Throws:
 * - ApiError (status 401) when the refresh token is revoked or expired.
 * - NetworkError when the API is unreachable.
 */
export async function refresh(refreshTokenValue: string): Promise<StoredSession> {
  const url = `${resolveBaseUrl()}/auth/refresh`;
  const response = await safeFetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken: refreshTokenValue, deviceLabel: 'tribely-cli' }),
  });

  if (!response.ok) {
    await throwFromResponse(response);
  }

  const body = (await response.json()) as AuthApiResponse;
  return toStoredSession(body);
}

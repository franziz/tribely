import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { StoredSession } from '../session/session.types.js';
import { ApiError, NetworkError } from './errors.js';

// Restore env and fetch stubs between tests.
let originalApiBaseUrl: string | undefined;

beforeEach(() => {
  originalApiBaseUrl = process.env.API_BASE_URL;
});

afterEach(() => {
  if (originalApiBaseUrl === undefined) {
    delete process.env.API_BASE_URL;
  } else {
    process.env.API_BASE_URL = originalApiBaseUrl;
  }
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const ACCESS_TOKEN = { value: 'at-value', expiresAt: '2099-01-01T00:00:00.000Z' };
const REFRESH_TOKEN = { value: 'rt-value', expiresAt: '2099-06-01T00:00:00.000Z' };
const USER_DTO = {
  id: 'user-1',
  email: 'test@example.com',
  displayName: 'Tester',
  emailVerifiedAt: null,
  bio: null,
  avatarUrl: null,
  languages: [],
  interests: [],
  currentCity: null,
  travelerType: null,
  createdAt: '2024-01-01T00:00:00.000Z',
  updatedAt: '2024-01-01T00:00:00.000Z',
};

const AUTH_API_RESPONSE = {
  user: USER_DTO,
  accessToken: ACCESS_TOKEN,
  refreshToken: REFRESH_TOKEN,
};

const EXPECTED_SESSION: StoredSession = {
  user: { id: 'user-1', email: 'test@example.com', displayName: 'Tester' },
  accessToken: ACCESS_TOKEN,
  refreshToken: REFRESH_TOKEN,
};

/** Helper to build a mock fetch Response. */
function mockResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// ---------------------------------------------------------------------------
// resolveBaseUrl
// ---------------------------------------------------------------------------

describe('resolveBaseUrl', () => {
  it('returns API_BASE_URL when set', async () => {
    process.env.API_BASE_URL = 'https://api.example.com';
    const { resolveBaseUrl } = await import('./api-client.js');
    expect(resolveBaseUrl()).toBe('https://api.example.com');
  });

  it('defaults to http://localhost:3000 when API_BASE_URL is unset', async () => {
    delete process.env.API_BASE_URL;
    const { resolveBaseUrl } = await import('./api-client.js');
    expect(resolveBaseUrl()).toBe('http://localhost:3000');
  });
});

// ---------------------------------------------------------------------------
// login
// ---------------------------------------------------------------------------

describe('login', () => {
  it('maps a 200 response to a StoredSession', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(mockResponse(AUTH_API_RESPONSE, 200)));

    const { login } = await import('./api-client.js');
    const result = await login('test@example.com', 'secret');

    expect(result).toEqual(EXPECTED_SESSION);
  });

  it('throws ApiError with the server message on 401', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        mockResponse({ error: { code: 'UNAUTHORIZED', message: 'Invalid credentials' } }, 401),
      ),
    );

    const { login } = await import('./api-client.js');
    await expect(login('bad@example.com', 'wrong')).rejects.toSatisfy(
      (err: unknown) =>
        err instanceof ApiError && err.message === 'Invalid credentials' && err.status === 401,
    );
  });

  it('throws ApiError and NOT a raw object on 401', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        mockResponse({ error: { code: 'UNAUTHORIZED', message: 'Invalid credentials' } }, 401),
      ),
    );

    const { login } = await import('./api-client.js');
    const caught = await login('bad@example.com', 'wrong').catch((e: unknown) => e);

    expect(caught).toBeInstanceOf(ApiError);
    expect(typeof caught).toBe('object');
    // Must be an Error instance, not a raw envelope object.
    expect((caught as Error).message).toBe('Invalid credentials');
  });

  it('throws NetworkError when fetch rejects (ECONNREFUSED / ENOTFOUND)', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockRejectedValue(new Error('ECONNREFUSED')),
    );

    const { login } = await import('./api-client.js');
    await expect(login('test@example.com', 'pass')).rejects.toBeInstanceOf(NetworkError);
  });

  it('does NOT call saveSession — login only returns the session (AC8b)', async () => {
    // This test documents the contract: login() is a pure data call.
    // The command handler (Brief 3) decides when to persist.
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(mockResponse(AUTH_API_RESPONSE, 200)));

    const sessionStore = await import('../session/session-store.js');
    const saveSpy = vi.spyOn(sessionStore, 'saveSession');

    const { login } = await import('./api-client.js');
    await login('test@example.com', 'secret');

    expect(saveSpy).not.toHaveBeenCalled();
  });
});

// ---------------------------------------------------------------------------
// whoami
// ---------------------------------------------------------------------------

describe('whoami', () => {
  it('returns AuthUserDto on 200', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(mockResponse(USER_DTO, 200)));

    const { whoami } = await import('./api-client.js');
    const result = await whoami('at-value');

    expect(result).toEqual(USER_DTO);
  });

  it('throws ApiError on 401', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        mockResponse({ error: { code: 'UNAUTHORIZED', message: 'Token expired' } }, 401),
      ),
    );

    const { whoami } = await import('./api-client.js');
    await expect(whoami('stale-token')).rejects.toSatisfy(
      (err: unknown) => err instanceof ApiError && err.status === 401,
    );
  });
});

// ---------------------------------------------------------------------------
// refresh
// ---------------------------------------------------------------------------

describe('refresh', () => {
  it('maps a 200 response to a rotated StoredSession', async () => {
    const rotated = {
      ...AUTH_API_RESPONSE,
      accessToken: { value: 'new-at', expiresAt: '2099-02-01T00:00:00.000Z' },
      refreshToken: { value: 'new-rt', expiresAt: '2099-07-01T00:00:00.000Z' },
    };
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(mockResponse(rotated, 200)));

    const { refresh } = await import('./api-client.js');
    const result = await refresh('rt-value');

    expect(result.accessToken.value).toBe('new-at');
    expect(result.refreshToken.value).toBe('new-rt');
  });

  it('throws ApiError on 401 (refresh token revoked)', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        mockResponse({ error: { code: 'UNAUTHORIZED', message: 'Refresh token revoked' } }, 401),
      ),
    );

    const { refresh } = await import('./api-client.js');
    await expect(refresh('bad-rt')).rejects.toSatisfy(
      (err: unknown) => err instanceof ApiError && err.status === 401,
    );
  });
});

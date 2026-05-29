import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { StoredSession } from './session.types.js';
import { ApiError, NotLoggedInError, SessionExpiredError } from '../api/errors.js';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const FUTURE_ISO = '2099-01-01T00:00:00.000Z';
const PAST_ISO = '2000-01-01T00:00:00.000Z';

function makeSession(overrides?: Partial<StoredSession['accessToken']>): StoredSession {
  return {
    user: { id: 'user-1', email: 'test@example.com', displayName: 'Tester' },
    accessToken: {
      value: 'at-value',
      expiresAt: FUTURE_ISO,
      ...overrides,
    },
    refreshToken: { value: 'rt-value', expiresAt: FUTURE_ISO },
  };
}

// ---------------------------------------------------------------------------
// Module-level mocks
// ---------------------------------------------------------------------------

// We mock the two sibling modules so tests have full control without touching
// the real filesystem or network.
vi.mock('./session-store.js', () => ({
  loadSession: vi.fn(),
  saveSession: vi.fn(),
}));

vi.mock('../api/api-client.js', () => ({
  refresh: vi.fn(),
}));

const sessionStore = await import('./session-store.js');
const apiClient = await import('../api/api-client.js');
const { getValidAccessToken } = await import('./session-manager.js');

beforeEach(() => {
  vi.clearAllMocks();
});

afterEach(() => {
  vi.restoreAllMocks();
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('getValidAccessToken', () => {
  it('throws NotLoggedInError when no session is on disk', async () => {
    vi.mocked(sessionStore.loadSession).mockReturnValue(null);

    await expect(getValidAccessToken()).rejects.toBeInstanceOf(NotLoggedInError);
    expect(apiClient.refresh).not.toHaveBeenCalled();
  });

  it('returns the stored access token when it is not near expiry', async () => {
    vi.mocked(sessionStore.loadSession).mockReturnValue(makeSession({ expiresAt: FUTURE_ISO }));

    const token = await getValidAccessToken();

    expect(token).toBe('at-value');
    expect(apiClient.refresh).not.toHaveBeenCalled();
    expect(sessionStore.saveSession).not.toHaveBeenCalled();
  });

  it('refreshes silently when the access token is already expired', async () => {
    const expired = makeSession({ expiresAt: PAST_ISO });
    const rotated: StoredSession = {
      ...expired,
      accessToken: { value: 'new-at', expiresAt: FUTURE_ISO },
      refreshToken: { value: 'new-rt', expiresAt: FUTURE_ISO },
    };
    vi.mocked(sessionStore.loadSession).mockReturnValue(expired);
    vi.mocked(apiClient.refresh).mockResolvedValue(rotated);

    const token = await getValidAccessToken();

    expect(apiClient.refresh).toHaveBeenCalledWith('rt-value');
    expect(sessionStore.saveSession).toHaveBeenCalledWith(rotated);
    expect(token).toBe('new-at');
  });

  it('refreshes when the access token expires within the 30s buffer', async () => {
    // Expiry 10 seconds from now — inside the 30s buffer.
    const soonExpiry = new Date(Date.now() + 10_000).toISOString();
    const nearExpired = makeSession({ expiresAt: soonExpiry });
    const rotated: StoredSession = {
      ...nearExpired,
      accessToken: { value: 'new-at', expiresAt: FUTURE_ISO },
    };
    vi.mocked(sessionStore.loadSession).mockReturnValue(nearExpired);
    vi.mocked(apiClient.refresh).mockResolvedValue(rotated);

    const token = await getValidAccessToken();

    expect(apiClient.refresh).toHaveBeenCalled();
    expect(token).toBe('new-at');
  });

  it('throws SessionExpiredError when refresh returns 401', async () => {
    const expired = makeSession({ expiresAt: PAST_ISO });
    vi.mocked(sessionStore.loadSession).mockReturnValue(expired);
    vi.mocked(apiClient.refresh).mockRejectedValue(new ApiError('Token revoked', 401));

    await expect(getValidAccessToken()).rejects.toBeInstanceOf(SessionExpiredError);
    // saveSession must NOT be called when refresh fails.
    expect(sessionStore.saveSession).not.toHaveBeenCalled();
  });

  it('re-throws non-401 ApiError from refresh without wrapping', async () => {
    const expired = makeSession({ expiresAt: PAST_ISO });
    vi.mocked(sessionStore.loadSession).mockReturnValue(expired);
    const serverError = new ApiError('Server error', 500);
    vi.mocked(apiClient.refresh).mockRejectedValue(serverError);

    await expect(getValidAccessToken()).rejects.toBe(serverError);
  });
});

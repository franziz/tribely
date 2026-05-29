import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { StoredSession } from '../session/session.types.js';
import { SessionExpiredError } from '../api/errors.js';
import type { AuthUserDto } from '../api/api-client.js';

// ---------------------------------------------------------------------------
// Module-level mocks
// ---------------------------------------------------------------------------

vi.mock('../session/session-store.js', () => ({
  loadSession: vi.fn(),
  saveSession: vi.fn(),
  clearSession: vi.fn(),
  isStoredSession: vi.fn(),
}));

vi.mock('../api/api-client.js', () => ({
  whoami: vi.fn(),
  login: vi.fn(),
  refresh: vi.fn(),
  resolveBaseUrl: vi.fn(),
}));

vi.mock('../session/session-manager.js', () => ({
  getValidAccessToken: vi.fn(),
}));

const sessionStore = await import('../session/session-store.js');
const apiClient = await import('../api/api-client.js');
const sessionManager = await import('../session/session-manager.js');
const { authWhoamiAction } = await import('./auth-whoami.js');

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const FUTURE_ISO = '2099-01-01T00:00:00.000Z';

function makeSession(): StoredSession {
  return {
    user: { id: 'user-1', email: 'test@example.com', displayName: 'Tester' },
    accessToken: { value: 'at-value', expiresAt: FUTURE_ISO },
    refreshToken: { value: 'rt-value', expiresAt: FUTURE_ISO },
  };
}

const USER_DTO: AuthUserDto = {
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

let consoleLogSpy: ReturnType<typeof vi.spyOn>;

beforeEach(() => {
  vi.clearAllMocks();
  consoleLogSpy = vi.spyOn(console, 'log').mockImplementation(() => undefined);
});

afterEach(() => {
  vi.restoreAllMocks();
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('authWhoamiAction', () => {
  describe('no session on disk', () => {
    it('prints "Not logged in" and does NOT call whoami', async () => {
      vi.mocked(sessionStore.loadSession).mockReturnValue(null);

      await authWhoamiAction();

      expect(consoleLogSpy).toHaveBeenCalledWith('Not logged in');
      expect(apiClient.whoami).not.toHaveBeenCalled();
      expect(sessionManager.getValidAccessToken).not.toHaveBeenCalled();
    });

    it('exits 0 (no error thrown) when there is no session', async () => {
      vi.mocked(sessionStore.loadSession).mockReturnValue(null);

      // Should resolve without throwing — callers depend on this for AC4/AC8a.
      await expect(authWhoamiAction()).resolves.toBeUndefined();
    });
  });

  describe('valid session on disk', () => {
    it('calls getValidAccessToken then whoami and prints identity', async () => {
      vi.mocked(sessionStore.loadSession).mockReturnValue(makeSession());
      vi.mocked(sessionManager.getValidAccessToken).mockResolvedValue('at-value');
      vi.mocked(apiClient.whoami).mockResolvedValue(USER_DTO);

      await authWhoamiAction();

      expect(sessionManager.getValidAccessToken).toHaveBeenCalledOnce();
      expect(apiClient.whoami).toHaveBeenCalledWith('at-value');
      expect(consoleLogSpy).toHaveBeenCalledWith('id:          user-1');
      expect(consoleLogSpy).toHaveBeenCalledWith('email:       test@example.com');
      expect(consoleLogSpy).toHaveBeenCalledWith('displayName: Tester');
    });
  });

  describe('session expired', () => {
    it('throws SessionExpiredError when getValidAccessToken rejects with it', async () => {
      vi.mocked(sessionStore.loadSession).mockReturnValue(makeSession());
      vi.mocked(sessionManager.getValidAccessToken).mockRejectedValue(
        new SessionExpiredError(),
      );

      await expect(authWhoamiAction()).rejects.toBeInstanceOf(SessionExpiredError);
      expect(apiClient.whoami).not.toHaveBeenCalled();
    });
  });
});

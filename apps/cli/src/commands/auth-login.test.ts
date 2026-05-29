import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { StoredSession } from '../session/session.types.js';
import { ApiError } from '../api/errors.js';

// ---------------------------------------------------------------------------
// Module-level mocks
// ---------------------------------------------------------------------------

vi.mock('../api/api-client.js', () => ({
  login: vi.fn(),
  whoami: vi.fn(),
  refresh: vi.fn(),
  resolveBaseUrl: vi.fn(),
}));

vi.mock('../session/session-store.js', () => ({
  loadSession: vi.fn(),
  saveSession: vi.fn(),
  clearSession: vi.fn(),
  isStoredSession: vi.fn(),
}));

// Prompt helpers — mock so tests don't hang on stdin.
vi.mock('../prompt/prompt.js', () => ({
  promptText: vi.fn(),
  promptPassword: vi.fn(),
}));

const apiClient = await import('../api/api-client.js');
const sessionStore = await import('../session/session-store.js');
const promptHelpers = await import('../prompt/prompt.js');
const { authLoginAction } = await import('./auth-login.js');

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const FUTURE_ISO = '2099-01-01T00:00:00.000Z';

const MOCK_SESSION: StoredSession = {
  user: { id: 'user-1', email: 'test@example.com', displayName: 'Tester' },
  accessToken: { value: 'at-value', expiresAt: FUTURE_ISO },
  refreshToken: { value: 'rt-value', expiresAt: FUTURE_ISO },
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

let consoleLogSpy: ReturnType<typeof vi.spyOn>;

beforeEach(() => {
  vi.clearAllMocks();
  consoleLogSpy = vi.spyOn(console, 'log').mockImplementation(() => undefined);

  // Default prompt answers.
  vi.mocked(promptHelpers.promptText).mockResolvedValue('test@example.com');
  vi.mocked(promptHelpers.promptPassword).mockResolvedValue('secret');
});

afterEach(() => {
  vi.restoreAllMocks();
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('authLoginAction', () => {
  describe('success path', () => {
    it('calls saveSession with the session returned by login', async () => {
      vi.mocked(apiClient.login).mockResolvedValue(MOCK_SESSION);

      await authLoginAction();

      expect(apiClient.login).toHaveBeenCalledWith('test@example.com', 'secret');
      expect(sessionStore.saveSession).toHaveBeenCalledWith(MOCK_SESSION);
    });

    it('prints "Logged in as <email>" after a successful login', async () => {
      vi.mocked(apiClient.login).mockResolvedValue(MOCK_SESSION);

      await authLoginAction();

      expect(consoleLogSpy).toHaveBeenCalledWith('Logged in as test@example.com');
    });
  });

  describe('invalid credentials path (AC3)', () => {
    it('throws ApiError without calling saveSession when login fails', async () => {
      vi.mocked(apiClient.login).mockRejectedValue(
        new ApiError('Invalid credentials', 401),
      );

      await expect(authLoginAction()).rejects.toBeInstanceOf(ApiError);
      expect(sessionStore.saveSession).not.toHaveBeenCalled();
    });

    it('does not call saveSession on ApiError — prior session on disk untouched (AC8b)', async () => {
      vi.mocked(apiClient.login).mockRejectedValue(
        new ApiError('Invalid credentials', 401),
      );

      // Confirm saveSession is never reached on failure.
      await expect(authLoginAction()).rejects.toThrow();
      expect(sessionStore.saveSession).not.toHaveBeenCalled();
    });
  });
});

import { existsSync, mkdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { StoredSession } from './session.types.js';

// ---------------------------------------------------------------------------
// We override `os.homedir` so the module under test writes to a temp dir
// rather than the real ~/.tribely.
// ---------------------------------------------------------------------------

const testHome = join(tmpdir(), `tribely-cli-test-${process.pid.toString()}`);

vi.mock('node:os', async (importOriginal) => {
  const actual = await importOriginal<typeof import('node:os')>();
  return { ...actual, homedir: () => testHome };
});

// Import AFTER mocking so the module picks up the overridden homedir.
const { loadSession, saveSession, clearSession } = await import('./session-store.js');

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const SESSION: StoredSession = {
  user: { id: 'user-1', email: 'test@example.com', displayName: 'Tester' },
  accessToken: { value: 'access-abc', expiresAt: '2099-01-01T00:00:00.000Z' },
  refreshToken: { value: 'refresh-xyz', expiresAt: '2099-06-01T00:00:00.000Z' },
};

const configDir = join(testHome, '.tribely');
const configPath = join(configDir, 'config.json');

// ---------------------------------------------------------------------------
// Setup / teardown
// ---------------------------------------------------------------------------

beforeEach(() => {
  // Ensure the test home exists but .tribely is absent so each test starts clean.
  mkdirSync(testHome, { recursive: true });
  if (existsSync(configDir)) {
    rmSync(configDir, { recursive: true, force: true });
  }
});

afterEach(() => {
  vi.restoreAllMocks();
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('loadSession', () => {
  it('returns null when the config file does not exist', () => {
    expect(loadSession()).toBeNull();
  });

  it('returns null when the config file contains malformed JSON', () => {
    mkdirSync(configDir, { recursive: true, mode: 0o700 });
    writeFileSync(configPath, '{ not valid json', { mode: 0o600 });
    expect(loadSession()).toBeNull();
  });

  it('returns null when the config file contains valid JSON that fails the type guard', () => {
    mkdirSync(configDir, { recursive: true, mode: 0o700 });
    writeFileSync(configPath, JSON.stringify({ foo: 'bar' }), { mode: 0o600 });
    expect(loadSession()).toBeNull();
  });

  it('round-trips: loaded session equals saved session', () => {
    saveSession(SESSION);
    const loaded = loadSession();
    expect(loaded).toEqual(SESSION);
  });

  it('emits a stderr warning when the file has group/world-readable bits but still returns the session', () => {
    mkdirSync(configDir, { recursive: true, mode: 0o700 });
    // 0o644 has group + world read bits set.
    writeFileSync(configPath, JSON.stringify(SESSION), { mode: 0o644 });

    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {
      /* suppress */
    });
    const result = loadSession();

    expect(result).toEqual(SESSION);
    expect(errorSpy).toHaveBeenCalledOnce();
    expect(errorSpy.mock.calls[0]?.[0]).toContain('WARNING');
  });
});

describe('saveSession', () => {
  it('creates the config directory with mode 0700', () => {
    saveSession(SESSION);
    const dirStats = statSync(configDir);
    expect(dirStats.mode & 0o777).toBe(0o700);
  });

  it('writes the config file with mode 0600', () => {
    saveSession(SESSION);
    const fileStats = statSync(configPath);
    expect(fileStats.mode & 0o777).toBe(0o600);
  });

  it('overwrites an existing session atomically (re-login)', () => {
    saveSession(SESSION);
    const updated: StoredSession = {
      ...SESSION,
      user: { ...SESSION.user, email: 'new@example.com' },
    };
    saveSession(updated);
    expect(loadSession()).toEqual(updated);
  });
});

describe('clearSession', () => {
  it('deletes the config file when it exists', () => {
    saveSession(SESSION);
    expect(existsSync(configPath)).toBe(true);
    clearSession();
    expect(existsSync(configPath)).toBe(false);
  });

  it('does not throw when the config file does not exist', () => {
    expect(() => {
      clearSession();
    }).not.toThrow();
  });
});

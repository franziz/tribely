/**
 * Config-file session store — persists StoredSession to ~/.tribely/config.json.
 *
 * Security properties:
 * - Directory created with mode 0700 (owner-only).
 * - File written atomically (tmp → rename) with mode 0600 so the plaintext
 *   bearer token is never even momentarily world-readable.
 * - On load, if group/world bits are set a warning is emitted but the session
 *   is still returned (operator's machine, operator's problem to fix perms).
 */

import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import type { StoredSession } from './session.types.js';

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

function configDir(): string {
  return join(homedir(), '.tribely');
}

function configPath(): string {
  return join(configDir(), 'config.json');
}

function configTmpPath(): string {
  return join(configDir(), 'config.json.tmp');
}

// ---------------------------------------------------------------------------
// Type guard — hand-written, no Zod
// ---------------------------------------------------------------------------

function isTokenField(v: unknown): v is { value: string; expiresAt: string } {
  return (
    v !== null &&
    typeof v === 'object' &&
    'value' in v &&
    typeof (v as Record<string, unknown>).value === 'string' &&
    'expiresAt' in v &&
    typeof (v as Record<string, unknown>).expiresAt === 'string'
  );
}

export function isStoredSession(v: unknown): v is StoredSession {
  if (v === null || typeof v !== 'object') return false;
  const obj = v as Record<string, unknown>;
  return (
    isTokenField(obj.accessToken) &&
    isTokenField(obj.refreshToken) &&
    obj.user !== null &&
    typeof obj.user === 'object' &&
    typeof (obj.user as Record<string, unknown>).id === 'string' &&
    typeof (obj.user as Record<string, unknown>).email === 'string' &&
    typeof (obj.user as Record<string, unknown>).displayName === 'string'
  );
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Load the persisted session from disk.
 *
 * Returns null when:
 * - The config file does not exist.
 * - The file content is malformed / fails the type guard.
 *
 * If the file exists but has group/world-readable bits set, emits a one-line
 * warning to stderr and returns the session anyway.
 */
export function loadSession(): StoredSession | null {
  const path = configPath();

  if (!existsSync(path)) {
    return null;
  }

  try {
    const stats = statSync(path);
    if ((stats.mode & 0o077) !== 0) {
      console.error(
        `[tribely] WARNING: ${path} has group/world-readable permissions. Run: chmod 600 ${path}`,
      );
    }

    const raw = readFileSync(path, 'utf-8');
    const parsed: unknown = JSON.parse(raw);

    if (!isStoredSession(parsed)) {
      return null;
    }

    return parsed;
  } catch {
    return null;
  }
}

/**
 * Persist a session to disk atomically.
 *
 * - Creates ~/.tribely/ with mode 0700 if absent.
 * - Writes to a tmp file with mode 0600, then renames into place.
 * - End-state: file 0600, directory 0700.
 */
export function saveSession(s: StoredSession): void {
  const dir = configDir();
  const tmp = configTmpPath();
  const path = configPath();

  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true, mode: 0o700 });
  }

  const content = JSON.stringify(s, null, 2);

  // Write tmp with mode 0600, then rename atomically into place.
  writeFileSync(tmp, content, { mode: 0o600, encoding: 'utf-8' });
  renameSync(tmp, path);
}

/**
 * Remove the persisted session from disk.
 * No-ops silently if the file does not exist.
 */
export function clearSession(): void {
  const path = configPath();
  if (existsSync(path)) {
    unlinkSync(path);
  }
}

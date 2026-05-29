/**
 * Tests for the top-level handleTopLevelError function extracted from main.ts.
 *
 * Covers:
 * - ApiError → process.exitCode = 1, clean message to stderr
 * - NetworkError → same
 * - SessionExpiredError → same
 * - NotLoggedInError → same
 * - Unknown error → generic message (no stack/body dumped) + exit 1
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, NetworkError, SessionExpiredError, NotLoggedInError } from './api/errors.js';

// Dynamically import so each test group gets a clean module snapshot.
// handleTopLevelError is a pure function — no side-effects on import.
const { handleTopLevelError } = await import('./main.js');

let consoleErrorSpy: ReturnType<typeof vi.spyOn>;
let originalExitCode: number | undefined;

beforeEach(() => {
  consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => undefined);
  originalExitCode = process.exitCode as number | undefined;
  process.exitCode = 0;
});

afterEach(() => {
  process.exitCode = originalExitCode;
  vi.restoreAllMocks();
});

describe('handleTopLevelError', () => {
  it('sets process.exitCode = 1 and prints message on ApiError', () => {
    handleTopLevelError(new ApiError('Invalid credentials', 401));

    expect(process.exitCode).toBe(1);
    expect(consoleErrorSpy).toHaveBeenCalledWith('Invalid credentials');
  });

  it('sets process.exitCode = 1 and prints message on NetworkError', () => {
    handleTopLevelError(new NetworkError('Unable to reach the API'));

    expect(process.exitCode).toBe(1);
    expect(consoleErrorSpy).toHaveBeenCalledWith('Unable to reach the API');
  });

  it('sets process.exitCode = 1 and prints message on SessionExpiredError', () => {
    handleTopLevelError(new SessionExpiredError());

    expect(process.exitCode).toBe(1);
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      'Session expired, please run `tribely auth login` again',
    );
  });

  it('sets process.exitCode = 1 and prints message on NotLoggedInError', () => {
    handleTopLevelError(new NotLoggedInError());

    expect(process.exitCode).toBe(1);
    expect(consoleErrorSpy).toHaveBeenCalledWith('Not logged in — run `tribely auth login` first');
  });

  it('prints a generic message (no stack) for unexpected errors (AC3)', () => {
    const unexpected = new Error('INTERNAL: db connection pool exhausted');
    unexpected.stack = 'Error: INTERNAL: db connection pool exhausted\n  at foo.ts:1:1';

    handleTopLevelError(unexpected);

    expect(process.exitCode).toBe(1);
    // Must NOT print the raw stack or internal message.
    expect(consoleErrorSpy).not.toHaveBeenCalledWith(expect.stringContaining('INTERNAL'));
    expect(consoleErrorSpy).not.toHaveBeenCalledWith(expect.stringContaining('at foo.ts'));
    // Must print some generic human-readable message.
    expect(consoleErrorSpy).toHaveBeenCalledWith(expect.stringContaining('unexpected'));
  });

  it('handles non-Error thrown values gracefully', () => {
    handleTopLevelError('string error');

    expect(process.exitCode).toBe(1);
    expect(consoleErrorSpy).toHaveBeenCalledWith(expect.stringContaining('unexpected'));
  });
});

import { Command } from 'commander';
import pkg from '../package.json' with { type: 'json' };
import { authLoginAction } from './commands/auth-login.js';
import { authWhoamiAction } from './commands/auth-whoami.js';
import { ApiError, NetworkError, SessionExpiredError, NotLoggedInError } from './api/errors.js';

// ---------------------------------------------------------------------------
// Top-level error handler — extracted for testability.
// Converts known typed errors to clean stderr messages + exit code 1.
// Any unexpected error emits a generic message (no raw stack/body per AC3).
// ---------------------------------------------------------------------------

export function handleTopLevelError(err: unknown): void {
  if (
    err instanceof ApiError ||
    err instanceof NetworkError ||
    err instanceof SessionExpiredError ||
    err instanceof NotLoggedInError
  ) {
    console.error(err.message);
  } else {
    console.error('An unexpected error occurred. Please try again.');
  }
  process.exitCode = 1;
}

// ---------------------------------------------------------------------------
// Command tree
// ---------------------------------------------------------------------------

const program = new Command();

program
  .name('tribely')
  .description('Tribely operator CLI — manages the Tribely API over HTTP')
  .version(pkg.version);

const auth = program.command('auth').description('Authentication commands');

auth
  .command('login')
  .description('Authenticate with your Tribely account')
  .action(authLoginAction);

auth
  .command('whoami')
  .description('Show the currently authenticated identity')
  .action(authWhoamiAction);

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

try {
  await program.parseAsync();
} catch (err: unknown) {
  handleTopLevelError(err);
}

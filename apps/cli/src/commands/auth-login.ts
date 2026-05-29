/**
 * `tribely auth login` — authenticate with email + password and persist the
 * session to disk.
 *
 * AC2  — on success, prints "Logged in as <email>".
 * AC3  — invalid-cred error surfaces a clean message via the top-level handler.
 * AC5  — re-login: saveSession atomically overwrites any previous session.
 * AC8b — on network/API failure, saveSession is never reached so the prior
 *         session on disk remains untouched.
 */

import { login } from '../api/api-client.js';
import { promptText, promptPassword } from '../prompt/prompt.js';
import { saveSession } from '../session/session-store.js';

export async function authLoginAction(): Promise<void> {
  const email = await promptText('Email');
  const password = await promptPassword('Password');

  // login() throws ApiError or NetworkError on failure — both bubble to the
  // top-level try/catch in main.ts which prints err.message to stderr and
  // sets process.exitCode = 1.  saveSession is therefore never called on error.
  const session = await login(email, password);

  saveSession(session);

  console.log(`Logged in as ${session.user.email}`);
}

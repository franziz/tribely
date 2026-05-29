/**
 * `tribely auth whoami` — show the identity of the currently authenticated
 * operator.
 *
 * AC4  — if logged in, print id / email / displayName.
 * AC4  — if not logged in, print "Not logged in" to stdout and exit 0
 *         (a valid state query, not an error condition).
 * AC8a — no config file → same "Not logged in" path (loadSession returns null).
 *
 * The command routes through getValidAccessToken() (not the raw stored token)
 * so a near-expired access token is silently refreshed before the whoami call.
 */

import { whoami } from '../api/api-client.js';
import { SessionExpiredError } from '../api/errors.js';
import { loadSession } from '../session/session-store.js';
import { getValidAccessToken } from '../session/session-manager.js';

export async function authWhoamiAction(): Promise<void> {
  const session = loadSession();

  if (session === null) {
    // Not an error — operator simply hasn't logged in yet. Exit 0.
    console.log('Not logged in');
    return;
  }

  let accessToken: string;
  try {
    accessToken = await getValidAccessToken();
  } catch (err) {
    if (err instanceof SessionExpiredError) {
      // Print the typed message and exit non-zero via main's error handler.
      throw err;
    }
    throw err;
  }

  const user = await whoami(accessToken);

  console.log(`id:          ${user.id}`);
  console.log(`email:       ${user.email}`);
  console.log(`displayName: ${user.displayName}`);
}

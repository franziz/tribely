# @tribely/cli

Tribely operator CLI — manages the Tribely API over HTTP.

## Configuration

### `API_BASE_URL`

The base URL of the Tribely API.

- **Unset (default):** `http://localhost:3000` — local development against a locally running API server.
- **Production:** set to the deployed API URL before running any commands, e.g. `API_BASE_URL=https://api.gotribely.com tribely <command>`.

### Session storage

After a successful login the CLI writes an authenticated session to `~/.tribely/config.json`. This file contains access and refresh tokens; protect it with appropriate file permissions (`chmod 600`).

The stored session shape mirrors the API's `AuthResponse`:

```json
{
  "accessToken": { "value": "<jwt>", "expiresAt": "<iso-8601>" },
  "refreshToken": { "value": "<jwt>", "expiresAt": "<iso-8601>" },
  "user": { "id": "<cuid2>", "email": "<email>", "displayName": "<name>" }
}
```

To log out, delete `~/.tribely/config.json` or run `tribely logout`.

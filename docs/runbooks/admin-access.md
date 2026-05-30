# Verification Appeals & Admin Access Runbook

## 1. Scope

This runbook governs granting and revoking admin status to Tribely operators who need to perform verification-appeal review and selfie moderation via the admin HTTP endpoints (e.g., `POST /admin/users/:id/selfie/reject`, `POST /admin/users/:id/selfie/approve`). Admin status is stored as a boolean column `isAdmin` on the `users` table and is checked on every inbound request to admin-prefixed routes — no token rotation is needed when revoking.

At Singapore launch, Tribely operates with at most two admins. This runbook covers the SQL-level bootstrap process for the solo-operator scale. See [§5. Audit Posture](#5-audit-posture) for the forward path when admin count grows.

## 2. Prerequisites

- You have direct SQL access to the production Postgres database (via `psql`, a DB GUI, or the hosting provider's query console).
- You know the target operator's **email address** (preferred) or their **user ID** (the `id` column — a CUID2 value, e.g. `usr_abc123`).
- The operator's Tribely account already exists (they have registered and completed email verification). This runbook does not create accounts — it promotes an existing account to admin.

## 3. Grant Admin Status

### Email-based (preferred)

```sql
UPDATE users
SET "isAdmin" = true
WHERE email = 'operator@gotribely.com';
```

Replace `operator@gotribely.com` with the operator's registered Tribely account email.

### User-ID-based (alternative, for already-known user IDs)

```sql
UPDATE users
SET "isAdmin" = true
WHERE id = 'usr_abc123';
```

Use this form when the operator's email is not known but the `id` is on hand (e.g., from a prior `SELECT`).

> **Note:** `"isAdmin"` uses double quotes because Prisma generates a camelCase column name; the quotes are required for Postgres to match it case-sensitively.

## 4. Verify the Grant Took Effect

Run the following query immediately after the `UPDATE`:

```sql
SELECT id, email, "isAdmin"
FROM users
WHERE email = 'operator@gotribely.com';
```

The returned row should show `isAdmin = true`. Example expected output:

```
id           | email                       | isAdmin
-------------+-----------------------------+---------
usr_abc123   | operator@gotribely.com      | t
```

**Optional HTTP verification.** Have the operator obtain a fresh access token (log out and back in) and call any admin endpoint with it:

```bash
curl -X POST https://api.gotribely.com/admin/users/<some-user-id>/selfie/reject \
  -H "Authorization: Bearer <operator-access-token>" \
  -H "Content-Type: application/json" \
  -d '{"reason": "smoke-test"}'
```

A `200` (or any non-`401`/`403`) response confirms the admin middleware accepted the token. A `401`/`403` response means the grant did not propagate — re-check the `UPDATE` and confirm you are on the correct database.

> **No token rotation needed.** Admin status is read from the database on every request. The operator does not need to log out and back in for the grant to take effect on subsequent requests — but doing so refreshes the JWT timestamp and is good hygiene.

## 5. Revoke Admin Status

```sql
UPDATE users
SET "isAdmin" = false
WHERE email = 'operator@gotribely.com';
```

The revoke takes effect on the operator's **very next request** — the admin middleware re-reads `isAdmin` from the database on each call. No token invalidation, no cache flush, no deployment is required. Verify with the same `SELECT` from §4; `isAdmin` should return `f`.

## 6. Audit Posture

The grant and revoke operations described above are **direct SQL mutations**, not HTTP calls. They are **not** recorded in `http_audit_logs` (that table captures inbound HTTP request lifecycle, not out-of-band DB writes).

For PDPC discovery or an internal audit of who held admin at a given point in time, the source of truth is the **database backup tape** — the production Postgres point-in-time recovery log captures the `UPDATE` statement, the session user, and the timestamp. There is no application-layer audit row for these SQL operations.

This posture is **acceptable for the Singapore launch** given the two-admin operating scale. At two admins, admin grant history is fully reconstructable from backup tape with negligible forensic cost. If admin count grows or compliance requirements tighten, see §7.

## 7. Forward Path: `admin_grants` Audit Table

When a formal admin-grant audit trail becomes a compliance requirement (PDPC audit, App Store reviewer probe, or growth beyond the two-admin scale), the clean fix is to promote `users.isAdmin` to a small dedicated table:

```sql
CREATE TABLE admin_grants (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id),
  granted_by  TEXT NOT NULL REFERENCES users(id),
  granted_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_by  TEXT REFERENCES users(id),
  revoked_at  TIMESTAMPTZ
);
```

Admin status is then derived from the presence of an unrevoked row in `admin_grants` rather than from a boolean column on `users`. Every grant and revoke is an `INSERT` or `UPDATE` on this table — fully attributable, durable, and queryable without touching backup tape. This migration is a single-feature change (domain VO, mapper, middleware query, and one migration) — not a rewrite. Track this as a future tech-debt ticket when the compliance requirement crystallises.

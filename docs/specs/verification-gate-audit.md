# Verification gate audit — mutating HTTP endpoints

Owner: engineering-lead
Status: Authoritative as of TRI-117 (2026-05-19)
Spec source: TRI-117
Convention source: TRI-15 (email gate), TRI-16 (phone gate)
Last updated: 2026-05-19

## 1. Convention

Every mutating HTTP endpoint (`POST`, `PATCH`, `PUT`, `DELETE`) MUST mount the
verification gate in the canonical order:

    requireAuth → requireVerifiedEmail → requireVerifiedPhone → (rate-limit) → zValidator → handler

Email-first ordering is contractual — an unverified user receives the email
error before the phone error. The middlewares throw `AppError.emailNotVerified`
(HTTP 403, code `EMAIL_NOT_VERIFIED`) and `AppError.phoneNotVerified` (HTTP 403,
code `PHONE_NOT_VERIFIED`) respectively.

## 2. Legitimate ungate categories

A mutating route MAY skip one or both gates only if it falls into one of these
categories. New ungated routes MUST classify themselves into a category in this
file in the same PR that introduces them.

- **A — Auth pre-JWT.** Endpoint accepts no bearer token; the caller has no
  identity yet. (sign-up, sign-in, refresh, sign-out, forgot/reset password.)
- **B — Verification-completion endpoint.** The endpoint's purpose is to move
  the caller from unverified to verified; gating it would be a deadlock.
  (verify-email, resend-verification, phone/start, phone/verify.)
- **C — Authenticated session-management with no business-state mutation.**
  Token rotation / sign-out-all. The caller is authenticated but the action
  cannot harm other users.

## 3. Per-route classification

| Method | Path | Gate posture | Classification | Notes |
| --- | --- | --- | --- | --- |
| POST | /auth/sign-up | none | A — auth pre-JWT | |
| POST | /auth/sign-in | none | A — auth pre-JWT | |
| POST | /auth/refresh | none | A — auth pre-JWT | |
| POST | /auth/sign-out | none | A — auth pre-JWT | Token in body |
| POST | /auth/sign-out-all | auth | C — session mgmt | |
| POST | /auth/verify-email | auth | B — verify-completion | |
| POST | /auth/resend-verification | auth | B — verify-completion | |
| POST | /auth/forgot-password | none | A — auth pre-JWT | |
| POST | /auth/reset-password | none | A — auth pre-JWT | |
| POST | /auth/phone/start | auth | B — verify-completion | |
| POST | /auth/phone/verify | auth | B — verify-completion | |
| PATCH | /users/me | auth + email + phone | Gated (TRI-117) | |
| POST | /events | auth + email + phone | Gated (TRI-15/16) | |
| PATCH | /events/:id | auth + email + phone | Gated (TRI-117) | |
| DELETE | /events/:id | auth + email + phone | Gated (TRI-117) | |
| POST | /events/:id/join-requests | auth + email + phone | Gated (TRI-15/16) | |
| POST | /join-requests/:id/approve | auth + email + phone | Gated (TRI-15/16) | |
| POST | /join-requests/:id/reject | auth + email + phone | Gated (TRI-15/16) | |
| DELETE | /join-requests/:id | auth + email + phone | Gated (TRI-15/16) | |

## 4. Re-running this audit

```bash
# Enumerate every mutating route definition:
grep -rE "\.(post|patch|put|delete)\(" apps/api/src/features/**/presentation/http/routes/*.routes.ts \
  | grep -v test
```

Walk the output, combine each per-route path with the prefix in
`apps/api/src/app.ts`'s `app.route(...)` calls, and compare against §3. Any new
row must appear in §3 within the same PR.

## 5. Out of scope (deliberate non-goals)

- `GET` endpoints — discovery is public by product design.
- Non-HTTP surfaces — consumers, cron jobs, CLI.
- RBAC / ownership checks (e.g., "only the host can delete their event") — a
  separate concern, audited and enforced inside use cases, not at the route
  middleware layer.

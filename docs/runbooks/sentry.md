# Sentry Error Tracking — Provisioning Runbook

**Status:** v1.0
**Owner:** Repo owner (one-time setup, post-merge)
**Linear:** TRI-12
**Last updated:** 2026-06-09

---

## 1. Purpose & scope

This runbook provisions the Sentry project for error tracking as required by TRI-12. It is a one-time setup performed by the repo owner after the TRI-12 code lands. It covers two activities:

1. **PDPA / data-protection setup** — legal requirements that must be satisfied before any DSN is wired into production. Read this section in full before touching the Sentry console.
2. **Provisioning steps** — creating the project, retrieving the DSN(s), wiring them into the API host and mobile build, and validating the live smoke test.

Sentry serves **both the API and the Flutter mobile app** from a single project, distinguished by `environment` tags.

---

## PDPA / data-protection setup (Legal & Compliance — TRI-12)

> **READ BEFORE CREATING THE SENTRY PROJECT.** Two of the steps below are
> IRREVERSIBLE after project/org creation. Get them right the first time.

### Step P1 — Create the org/project in the EU region (IRREVERSIBLE)

When creating the Sentry organisation/project, select the **EU data region**.
The resulting DSN must read `https://<key>@<org>.ingest.de.sentry.io/<project>`
(EU), NOT `...ingest.sentry.io` / `...ingest.us.sentry.io` (US).

- **Why:** PDPA s26 (Transfer Limitation) is engaged either way (any region is
  "outside Singapore"), but the EU regime (GDPR) provides a destination-law
  baseline of comparable protection on top of the Sentry DPA. The US default
  rests on contract alone. EU is a strictly stronger s26 posture at identical
  cost. Sentry offers no Singapore region, so EU is the best available fallback
  from our SG-resident default (cf. selfie storage, which IS SG-resident).
- **Region is fixed at creation.** Changing it later requires deleting and
  recreating the org/project. Verify the DSN host before wiring any SDK.

### Step P2 — Accept the Sentry Data Processing Addendum (DPA)

During account setup, accept/execute Sentry's standard DPA
(Functional Software, Inc.). This is the contractual mechanism that satisfies
BOTH the PDPA s12 data-protection-provisions chain (Sentry is a data
intermediary) AND the s26 cross-border transfer requirement. Record the
acceptance date.

- Add Sentry to the Tribely sub-processor inventory alongside Resend (email)
  and Twilio (SMS): vendor = Functional Software, Inc.; data = error telemetry
  + opaque user id; region = EU; DPA-accepted = <date>.
- Ensure Sentry is named in the Privacy Policy sub-processor list before public
  launch (PrivPolicy is in external-counsel drafting — add Sentry to the input
  list). Privacy contact: privacy@gotribely.com.

### Step P3 — Confirm the scrubbing floor is live (defense-in-depth)

The authoritative PII scrub is CLIENT-SIDE in the integration code's
`beforeSend` / `beforeBreadcrumb` (see TRI-12 acceptance criteria). Server-side
scrubbing runs only AFTER ingestion (after the border crossing) and is a SECOND
layer, never a substitute. In project settings:

- Enable the server-side Data Scrubber + add custom rules for email / E.164
  phone / token (`Bearer`, `eyJ`, `X-Amz-Signature`) patterns.
- Set event retention to <= 90 days (PDPA s25 — no business need beyond the
  debugging tail).

### Step P4 — Verify `sendDefaultPii: false` before going live

Confirm both SDKs (`@sentry/node`, `sentry_flutter`) set `sendDefaultPii: false`
explicitly. This is the hard floor: leaving it at the SDK default can auto-attach
client IP, request headers (incl. Authorization/Cookie), and request body — which
would silently undercut the in-region `http_audit_logs` minimization rule
("no body content stored", PDPA-friendly). Performance tracing, profiling, and
session replay MUST remain disabled (errors-only scope; replay captures UGC/faces
and reopens the full Legal review).

---

## 2. Create the Sentry project

1. Log in to Sentry at `https://sentry.io` and create a new organisation (or use an existing one).
2. **When prompted for region, select EU** (`https://*.ingest.de.sentry.io`). This is IRREVERSIBLE — verify the DSN host before proceeding past this screen.
3. Create a single project. Suggested name: `tribely`. Platform selection: `Node.js` (you will add the Flutter client key separately in step 3).
4. Both the API and the mobile app share this one project; runtime environment is distinguished via the `environment` tag (`production`, `staging`, `development`) set in each SDK's `init` call.

---

## 3. Retrieve the DSN(s)

Navigate to **Project Settings → Client Keys (DSN)**.

You have two valid options — the code is agnostic to which you choose:

**Option A — Single shared DSN (recommended for launch):**
Copy the single default DSN. Paste the same value into the API env var (`SENTRY_DSN`) and the mobile build-define (`SENTRY_DSN` in `apps/mobile/.env.json`). Both stacks send to the same ingest endpoint and are separated by the `environment` and `platform` context Sentry derives from the SDK. This minimises credential surface and is the right call for a single-team v1.

**Option B — Two client keys under one project:**
Under Client Keys, create a second key (e.g., `tribely-mobile`). Wire the first key into the API and the second into the mobile build-define. Events still land in the same project and share the same alert rules, but you can rate-limit or revoke each key independently. Add complexity only if you later need per-platform rate-limiting.

The DSN format must be `https://<key>@<org>.ingest.de.sentry.io/<project>`. Reject any DSN that does not contain `.de.sentry.io`.

---

## 4. Wire the DSN into the API host

Set the following env var on the production API host (do NOT commit the value):

```
SENTRY_DSN=https://<key>@<org>.ingest.de.sentry.io/<project>
```

**Env-var contract (`apps/api/src/core/config/env.ts` + `apps/api/.env.example`):**

- `SENTRY_DSN` blank (or absent) disables Sentry silently in development.
- In production (`NODE_ENV=production`), boot refuses a blank `SENTRY_DSN` with a clear error message — the same production-safety pattern used for `EMAIL_TRANSPORT`, `SMS_TRANSPORT`, and `STORAGE_TRANSPORT`. Do not remove that guard.
- See `apps/api/.env.example` for the placeholder comment and `apps/api/src/core/config/env.ts` for the Zod guard.

---

## 5. Wire the DSN into the mobile build

The Flutter app reads env values from `apps/mobile/.env.json` at build time via `--dart-define-from-file`. This file is git-ignored — it mirrors the pattern already used for `API_BASE_URL`.

Add the following entry to `apps/mobile/.env.json`:

```json
{
  "API_BASE_URL": "https://...",
  "SENTRY_DSN": "https://<key>@<org>.ingest.de.sentry.io/<project>"
}
```

For release / CI builds, supply the `.env.json` as a CI secret (same channel as `API_BASE_URL`) and pass it via `--dart-define-from-file=apps/mobile/.env.json` in the build command. Do not hardcode the DSN in source.

---

## 6. Server-side scrubbing (legal rules P3 — runbook layer)

In **Project Settings → Security & Privacy**:

1. **Enable Data Scrubber** — the built-in scrubber strips common PII patterns (emails, IPs, credit card numbers) from events before they are stored.
2. **Add custom scrubbing rules** for patterns the built-in scrubber does not cover:
   - Email pattern: `[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}`
   - E.164 phone: `\+[1-9]\d{6,14}`
   - Bearer token: `Bearer\s+[A-Za-z0-9\-._~+/]+=*`
   - JWT: `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+`
   - AWS presign signature: `X-Amz-Signature=[A-Fa-f0-9]+`
3. **Set event retention to 90 days** (the PDPA s25 maximum — go to **Project Settings → General** → Retention).

These settings are a second-layer defense. The authoritative scrub is client-side in `beforeSend` / `beforeBreadcrumb` (TRI-12 acceptance criteria). Server-side rules apply only after ingestion and do not substitute for SDK-level filtering.

---

## 7. Live smoke test

After wiring both stacks, trigger one controlled error per platform and confirm:

**API smoke test:**

```bash
# Trigger a deliberate 500 — in a staging environment, call an endpoint with
# a payload known to produce an unhandled exception, or temporarily add a
# throw statement behind a feature flag.
curl -X POST https://<api-host>/some-path -H "Authorization: Bearer <token>"
```

**Mobile smoke test:**

In a staging build, call `Sentry.captureException(Exception('smoke-test'))` once from a test screen or debug menu, then remove it before the production release.

**Verify in the Sentry dashboard** that:

- The event appears in the project within ~30 seconds.
- The event's `environment` tag matches the environment you triggered from (e.g., `staging`).

**Verify the event contains NONE of the following (forbidden substrings checklist):**

```
@                          # email address fragment
+65                        # Singapore E.164 country code prefix (phone)
Bearer                     # Authorization header value
eyJ                        # JWT fragment
X-Amz-Signature            # AWS presigned URL signature param
"details"                  # event/join-request details field (user-generated content)
"ip"                       # client IP field
"Authorization"            # Authorization header key
"Cookie"                   # Cookie header key
"password"                 # credential field
"token"                    # generic token field
```

Inspect the raw event JSON in Sentry (**Event → JSON** view) and grep for each substring. Any hit is a scrubbing failure — stop, fix the `beforeSend` hook in the SDK (TRI-12 acceptance criteria), re-verify before routing production traffic.

---

## 8. Follow-ups deferred (to be filed at TRI-12 closeout)

- **Source map / dSYM upload:** covered in §9 below (TRI-278). ~~Deferred to a follow-up ticket.~~
- **Alert rules:** configure Sentry alert rules (error rate spikes, new issue alerts) after confirming the smoke test passes. Not required for launch enablement.
- **Sub-processor inventory update:** once the DPA is accepted and the acceptance date is recorded (Step P2), update the internal sub-processor registry and hand the Sentry entry to external counsel for inclusion in the Privacy Policy before public launch.

---

## 9. Symbol & source-map upload (TRI-278)

This section documents how to produce fully symbolicated stack traces for both the API (TypeScript source maps) and the mobile app (Dart dSYM / obfuscation maps). It is gated on having an owner-supplied `SENTRY_AUTH_TOKEN`; without it every step is a safe no-op and does not block builds or launches.

### 9.1 Minting the auth token (owner's one-time out-of-band step)

This token is used only by upload tooling (`sentry-cli` and `sentry_dart_plugin`). It is **not** the DSN from §3 — do not confuse them.

1. Log in to [sentry.io](https://sentry.io) and navigate to **Settings → Auth Tokens**.
2. Click **Create New Token**.
3. Grant exactly these two scopes:
   - `project:releases`
   - `org:read`
4. No other scopes are needed. Do not grant `org:admin` or `project:write`.
5. Copy the token value immediately — it is only shown once.
6. Store it in your secrets manager / CI secrets store. Do NOT commit it.

### 9.2 API path — source maps via `tools/build.sh`

The upload is wired directly into the build script. When `SENTRY_AUTH_TOKEN` is set, `tools/build.sh` calls `upload_api_sourcemaps` (from `tools/scripts/lib/sentry.sh`) automatically after the Docker push. When the token is absent the step is a silent no-op — builds are byte-for-byte identical.

**Install `sentry-cli`:**

```bash
npm install -g @sentry/cli
# or via Homebrew on macOS:
brew install getsentry/tools/sentry-cli
```

Verify: `sentry-cli --version`

**Configure the build environment:**

Copy `tools/.env.build.example` to `tools/.env.build` (git-ignored) and fill in the three Sentry vars:

```bash
SENTRY_AUTH_TOKEN=sntrys_xxx   # token from §9.1
SENTRY_ORG=my-org              # Settings → Organisation → Organisation Slug
SENTRY_PROJECT=tribely         # Settings → Projects → your project → Project Slug
```

Source the file before running the build:

```bash
set -a && source tools/.env.build && set +a
bash tools/build.sh
```

Alternatively, export the vars in your shell session or CI environment directly.

**What the script does:**

1. Runs `npm run --workspace=@tribely/api build` to emit `apps/api/dist/**/*.js` + `*.js.map`.
2. Calls `sentry-cli sourcemap inject apps/api/dist` to inject `//# sourceMappingURL` references into the JS bundles.
3. Creates and finalises a Sentry release named `tribely-api@<docker-tag>` (e.g., `tribely-api@prd.42`).
4. Uploads all source maps under `apps/api/dist/` to that release.

**Release naming:** `tribely-api@<docker-tag>` — the `<docker-tag>` is the same `<type>.<n>` tag pushed to Docker Hub (e.g., `prd.42`, `uat.7`). The name is assembled inside `upload_api_sourcemaps` as `tribely-api@${tag}`.

**VPS runtime binding:** For Sentry to correlate live errors with the uploaded maps, the deployed API must emit the matching release identifier. On the VPS host, set:

```bash
SENTRY_RELEASE=tribely-api@prd.42   # match the deployed Docker tag exactly
```

This env var is documented in `apps/api/.env.example`. It is blank-allowed (absent means no release tag, degrading stack-trace readability but not causing a boot failure). Set it for every production and UAT deployment.

### 9.3 Mobile path — dSYM / obfuscation maps via `sentry_dart_plugin`

The plugin is declared in `apps/mobile/pubspec.yaml` under `dev_dependencies` (`sentry_dart_plugin: ^3.4.0`) and configured in the top-level `sentry:` block of the same file. It reads `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, and `SENTRY_PROJECT` from the environment.

**Before building:** ensure the same three env vars are set (same token and org/project slugs as §9.2).

**Build for release (Android):**

```bash
npm run mobile:build:apk:release
```

This runs Flutter with `--obfuscate --split-debug-info=build/symbols --extra-gen-snapshot-options=--save-obfuscation-map=build/app/obfuscation.map.json`, producing:

- `apps/mobile/build/symbols/` — native dSYM / `.so` debug info
- `apps/mobile/build/app/obfuscation.map.json` — Dart obfuscation map (used to resolve mangled Dart identifiers)

**Build for release (iOS):**

```bash
npm run mobile:build:ios:release
```

This runs `flutter build ios --release` with the same `--obfuscate --split-debug-info=build/symbols` flags. The iOS dSYM files are written to `apps/mobile/build/symbols/`.

**Upload symbols:**

```bash
npm run mobile:upload-symbols
```

This invokes `dart run sentry_dart_plugin` from inside `apps/mobile/`. The plugin reads the `sentry:` block in `pubspec.yaml` and uploads the contents of `build/symbols/` (native debug symbols) and `build/app/obfuscation.map.json` (Dart obfuscation map) to the Sentry project.

**Release naming:** The plugin derives the release identifier from the pubspec `version` field. With `version: 0.0.1+1` the release string is `tribely@0.0.1+1`. The runtime SDK composes the same string via `buildSentryRelease()` in `apps/mobile/lib/src/core/observability/sentry_bootstrap.dart` using `PackageInfo.fromPlatform()` — so the uploaded symbols and live events share the same release tag automatically.

**iOS verification:** Open the uploaded release in Sentry (**Releases → tribely@0.0.1+1 → Artifacts**) and confirm dSYM files for both `arm64` and the Dart snapshot appear. A missing dSYM means the `build/symbols/` path did not contain the expected output — re-check that the `--split-debug-info` flag was present in the build command.

**Android verification:** Confirm `.sym` / `.so` debug-info files appear under the same release. If the Dart obfuscation map is absent, the `build/app/obfuscation.map.json` path may not have been produced — verify the `--extra-gen-snapshot-options=--save-obfuscation-map=...` flag was passed (the `mobile:build:apk:release` script includes it by default).

### 9.4 AC verification (gated on first real release)

Run this check after the first deployment that includes source maps / symbols uploaded under a real release tag.

**API:**

1. In a staging environment, trigger a deliberate unhandled exception (e.g., temporarily throw inside an endpoint behind a feature flag).
2. Locate the event in the Sentry dashboard.
3. Verify the stack trace resolves to original `.ts` file + line (not minified JS line numbers).
4. Verify the event's `release` tag reads `tribely-api@<expected-tag>`.

**Mobile:**

1. In a staging release build, call `Sentry.captureException(Exception('symbol-smoke-test'))` once from a debug menu, then remove it before production.
2. Locate the event in Sentry.
3. Verify the Dart stack frames show original Dart identifiers and file:line (not mangled names like `minified$0`).
4. Verify the event's `release` tag reads `tribely@<version>+<build>` (e.g., `tribely@0.0.1+1`).

If either surface shows unresolved frames, the most common causes are:

- Release name mismatch between upload and runtime (check `SENTRY_RELEASE` on the API host; check `buildSentryRelease()` output against the pubspec version).
- Upload ran against the wrong build artefacts (rerun after a clean `flutter build` with the release flags).
- `sentry-cli` was not on PATH during the API build (the script warns but silently skips — install `sentry-cli` and rebuild).

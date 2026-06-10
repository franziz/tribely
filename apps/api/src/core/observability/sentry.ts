/**
 * Sentry error-monitoring module.
 *
 * THIS IS THE ONLY FILE IN THE REPO ALLOWED TO IMPORT '@sentry/node'.
 * All other files must consume the helpers exported from this module.
 * An ESLint no-restricted-imports rule (added in TRI-12) enforces this
 * boundary at lint time.
 *
 * Design decisions:
 * - Errors-only: `initWithoutDefaultIntegrations` +
 *   `getDefaultIntegrationsWithoutPerformance`. No tracing, no profiling, no
 *   replay. No `tracesSampleRate`. (Rule 4)
 * - Breadcrumb surface eliminated: filter out the 'Breadcrumbs' integration
 *   entirely from the default set. Prefer disabling over filtering-in-flight
 *   — less scrub surface to get wrong. (Rule 3)
 * - `sendDefaultPii: false` explicitly set. (Rule 1)
 * - `beforeSend: scrubEvent` registered; every event passes through the
 *   pure scrubber before egress. (Rule 2)
 * - `AppError.details` is NEVER serialized into extra/contexts. The capture
 *   helpers are the enforcement point; `scrubEvent` is the safety net. (Rule 8)
 * - User context reduced to `{ id }` only, sourced from ALS. (Rule 12)
 * - Request context is the allowlisted set: requestId, method, path
 *   (route template), status, errorCode, durationMs. (Rule 13)
 *
 * Initialisation:
 * - `initSentry()` is called once in `index.ts` `main()`, before `buildApp()`.
 * - No-ops when `SENTRY_DSN` is absent (dev / test environments).
 */
import * as Sentry from '@sentry/node';
import type { ErrorEvent } from '@sentry/node';
import { env } from '../config/env.js';
import { getRequestContext } from '../context/request-context.js';

// ---------------------------------------------------------------------------
// Regex catalogue for scrubEvent (Rule 9, Rule 5, Rule 11)
// ---------------------------------------------------------------------------

/** Email address — RFC-5322 simplified */
const RX_EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;

/** E.164 phone — Singapore (+65 XXXXXXXX) and general (+DDDDDDDDD) */
const RX_PHONE_SG = /\+?65\d{8,}/g;
const RX_PHONE_E164 = /\+\d{7,15}/g;

/** JWT — three base64url segments */
const RX_JWT = /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g;

/** Bearer token header value */
const RX_BEARER = /Bearer\s+[A-Za-z0-9._~+/-]+=*/gi;

/** Long hex strings ≥32 chars (API keys, secrets) */
const RX_HEX32 = /\b[0-9a-fA-F]{32,}\b/g;

/** Long base64 strings ≥32 chars (encoded payloads) */
const RX_B64_32 = /[A-Za-z0-9+/]{32,}={0,2}/g;

/** S3 signed-URL fragments (Rule 11) */
const RX_S3_SELFIES = /tribely-selfies-[^"'\s]*/g;
const RX_S3_AMZN = /X-Amz-(?:Signature|Credential)=[^"'\s&]*/gi;

// ---------------------------------------------------------------------------
// String scrubbing helpers
// ---------------------------------------------------------------------------

/**
 * Apply all PII + secret redaction regexes to a single string value.
 * Order matters: JWT before bearer (JWT is more specific), bearer before hex.
 */
const redactString = (s: string): string =>
  s
    .replace(RX_JWT, '[redacted-token]')
    .replace(RX_BEARER, '[redacted-token]')
    .replace(RX_EMAIL, '[redacted-email]')
    .replace(RX_PHONE_SG, '[redacted-phone]')
    .replace(RX_PHONE_E164, '[redacted-phone]')
    .replace(RX_S3_SELFIES, '[redacted-url]')
    .replace(RX_S3_AMZN, '[redacted-url]')
    .replace(RX_HEX32, '[redacted-token]')
    .replace(RX_B64_32, '[redacted-token]');

/**
 * Scrub a Sentry Request headers map.
 * Deletes Authorization, Cookie, Set-Cookie (Rules 5, 6) and redacts
 * any remaining string values. Returns a new `{ [key: string]: string }` map
 * matching Sentry's Request.headers type.
 */
const scrubHeaders = (
  headers: { [key: string]: string } | undefined,
): { [key: string]: string } | undefined => {
  if (!headers) return headers;
  const scrubbed: { [key: string]: string } = { ...headers };
  delete scrubbed['Authorization'];
  delete scrubbed['authorization'];
  delete scrubbed['Cookie'];
  delete scrubbed['cookie'];
  delete scrubbed['Set-Cookie'];
  delete scrubbed['set-cookie'];
  for (const [key, val] of Object.entries(scrubbed)) {
    scrubbed[key] = redactString(val);
  }
  return scrubbed;
};

// ---------------------------------------------------------------------------
// scrubEvent — pure, unit-testable beforeSend implementation
// ---------------------------------------------------------------------------

/**
 * Pure scrubber — the legal acceptance function for TRI-12.
 *
 * Typed as `(event: ErrorEvent): ErrorEvent` to match the `beforeSend` option
 * signature (Context7 confirmed: v8 uses `ErrorEvent`, not the broader `Event`
 * type). The `_hint` argument that Sentry passes is not needed — we ignore it
 * via the one-liner adapter below.
 *
 * Legal acceptance criteria enforced here:
 *   Rule 5  — drops Authorization + Bearer tokens from headers and message
 *   Rule 6  — drops Cookie / Set-Cookie from headers
 *   Rule 7  — deletes event.request.data (no request body ever attached)
 *   Rule 8  — deletes event.extra.details and any contexts.*.details
 *   Rule 9  — regex-redacts email, phone, JWT, bearer, long hex/b64 from
 *             message and exception values
 *   Rule 10 — clears event.user.ip_address
 *   Rule 11 — redacts tribely-selfies- / X-Amz-Signature / X-Amz-Credential
 *
 * Returns a new ErrorEvent object — does NOT mutate the input.
 * Must remain a pure function so unit tests can call it directly.
 */
export const scrubEvent = (event: ErrorEvent): ErrorEvent => {
  // Deep-clone the relevant subtrees so we never mutate Sentry's internal state.
  // We do a targeted clone rather than JSON.parse(JSON.stringify(...)) to avoid
  // losing non-serialisable values (Error objects on stack frames, etc.).
  const out: ErrorEvent = { ...event };

  // ── Request ──────────────────────────────────────────────────────────────
  if (out.request) {
    out.request = { ...out.request };

    // Rule 7 — no request body
    delete out.request.data;

    // Rule 5, 6 — scrub headers.
    // `scrubHeaders` returns `undefined` when the input is `undefined`.
    // With `exactOptionalPropertyTypes: true`, we must delete the optional
    // property rather than assign `undefined` to it.
    const scrubbedHeaders = scrubHeaders(out.request.headers);
    if (scrubbedHeaders !== undefined) {
      out.request.headers = scrubbedHeaders;
    } else {
      delete out.request.headers;
    }

    // Rule 11 — scrub request URL itself
    if (typeof out.request.url === 'string') {
      out.request.url = redactString(out.request.url);
    }
    // Rule 11 — scrub query string
    if (typeof out.request.query_string === 'string') {
      out.request.query_string = redactString(out.request.query_string);
    }
  }

  // ── User ─────────────────────────────────────────────────────────────────
  if (out.user) {
    // Rule 10, 12 — keep id only, no IP
    const userId = out.user.id;
    out.user = userId ? { id: userId } : {};
  }

  // ── Message ──────────────────────────────────────────────────────────────
  // Rule 9
  if (typeof out.message === 'string') {
    out.message = redactString(out.message);
  }

  // ── Exception values ─────────────────────────────────────────────────────
  // Rule 9 — redact exception.values[].value strings.
  // Exception.value is `string | undefined` per Sentry types — we only
  // redact when it IS a string; preserve the original value otherwise.
  if (out.exception?.values) {
    out.exception = {
      ...out.exception,
      values: out.exception.values.map((ex) =>
        typeof ex.value === 'string' ? { ...ex, value: redactString(ex.value) } : ex,
      ),
    };
  }

  // ── Extra ─────────────────────────────────────────────────────────────────
  // Rule 8 — delete details (AppError.details must never egress)
  if (out.extra) {
    out.extra = { ...out.extra };
    delete out.extra['details'];
    // Redact any remaining string values
    for (const [key, val] of Object.entries(out.extra)) {
      if (typeof val === 'string') {
        out.extra[key] = redactString(val);
      }
    }
  }

  // ── Contexts ─────────────────────────────────────────────────────────────
  // Rule 8 — delete details from every context object
  if (out.contexts) {
    out.contexts = { ...out.contexts };
    for (const [name, ctx] of Object.entries(out.contexts)) {
      if (ctx && typeof ctx === 'object' && 'details' in ctx) {
        const { details: _dropped, ...rest } = ctx as Record<string, unknown>;
        out.contexts[name] = rest;
      }
    }
  }

  return out;
};

// ---------------------------------------------------------------------------
// Initialisation
// ---------------------------------------------------------------------------

/**
 * Initialise Sentry once at boot. No-ops when `SENTRY_DSN` is blank.
 *
 * Must be called as the FIRST statement in `main()`, before `buildApp()`,
 * so that Sentry wraps all subsequent module loads.
 */
export const initSentry = (): void => {
  if (!env.SENTRY_DSN) return;

  // Use initWithoutDefaultIntegrations + getDefaultIntegrationsWithoutPerformance
  // to get errors-only behaviour: no tracing, no profiling. (Rule 4)
  // Then filter out the Breadcrumbs integration entirely to eliminate the
  // breadcrumb surface (Rule 3 — prefer disabling over filtering).
  Sentry.initWithoutDefaultIntegrations({
    dsn: env.SENTRY_DSN,
    environment: env.NODE_ENV,
    ...(env.SENTRY_RELEASE ? { release: env.SENTRY_RELEASE } : {}),

    // Rule 1 — explicitly disable PII capture
    sendDefaultPii: false,

    // Rule 4 — no tracing, no profiling, no replay
    // (tracesSampleRate is omitted entirely)

    integrations: [
      ...Sentry.getDefaultIntegrationsWithoutPerformance().filter((i) => i.name !== 'Breadcrumbs'),
    ],

    // Rule 2 — every event passes through the scrubber before egress.
    // The adapter ignores the `EventHint` second argument; `scrubEvent` stays
    // a single-argument pure function for direct use in unit tests.
    beforeSend: (event) => scrubEvent(event),
  });
};

// ---------------------------------------------------------------------------
// Capture helpers — the public API consumed by error-handler.ts
// ---------------------------------------------------------------------------

/**
 * Safe request context shape: allowlisted subset per Rule 13.
 */
export interface SentryRequestContext {
  readonly method: string;
  readonly path: string; // route template, NOT raw URL
  readonly status: number;
  readonly errorCode?: string;
  readonly durationMs?: number;
}

/**
 * Capture a handled AppError. Attaches allowlisted request context and user id.
 * AppError.details is deliberately NOT serialized here (Rule 8).
 */
export const captureAppError = (
  err: Error,
  context: SentryRequestContext,
  errorCode?: string,
): void => {
  if (!env.SENTRY_DSN) return;

  const requestCtx = getRequestContext();

  Sentry.withScope((scope) => {
    // Rule 12 — user is { id } only
    if (requestCtx?.actorUserId) {
      scope.setUser({ id: requestCtx.actorUserId });
    }

    // Rule 13 — allowlisted request context
    scope.setContext('request', {
      requestId: requestCtx?.requestId,
      method: context.method,
      path: context.path,
      status: context.status,
      errorCode: errorCode ?? context.errorCode,
      durationMs: context.durationMs,
    });

    Sentry.captureException(err);
  });
};

/**
 * Capture an unhandled error (500-class). Attaches allowlisted request context
 * and user id. Used in the unhandled branch of error-handler.ts.
 */
export const captureUnhandled = (err: unknown, context: SentryRequestContext): void => {
  if (!env.SENTRY_DSN) return;

  const requestCtx = getRequestContext();

  Sentry.withScope((scope) => {
    // Rule 12 — user is { id } only
    if (requestCtx?.actorUserId) {
      scope.setUser({ id: requestCtx.actorUserId });
    }

    // Rule 13 — allowlisted request context
    scope.setContext('request', {
      requestId: requestCtx?.requestId,
      method: context.method,
      path: context.path,
      status: context.status,
      errorCode: 'INTERNAL',
      durationMs: context.durationMs,
    });

    Sentry.captureException(err);
  });
};

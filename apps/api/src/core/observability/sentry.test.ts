/**
 * Unit tests for the Sentry scrubEvent pure function.
 *
 * These tests constitute the LEGAL ACCEPTANCE TEST for TRI-12 — they verify
 * the field-level PII scrub rules mandated by PDPA before any event egresses
 * to Sentry's servers.
 *
 * All tests call `scrubEvent` directly without any Sentry SDK involvement —
 * the function is pure and testable in isolation.
 */
import { describe, expect, it } from 'vitest';
import type { ErrorEvent } from '@sentry/node';
import { scrubEvent } from './sentry.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const makeEvent = (overrides: Partial<ErrorEvent> = {}): ErrorEvent => ({
  event_id: 'test-event-id',
  type: undefined,
  ...overrides,
});

// ---------------------------------------------------------------------------
// Rule 8 (SINGLE MOST IMPORTANT) — AppError.details must be stripped entirely
// ---------------------------------------------------------------------------

describe('Rule 8 — AppError.details stripped', () => {
  it('removes details from event.extra', () => {
    const event = makeEvent({
      extra: {
        details: { email: 'foo@bar.com', token: 'eyJabc.def.ghi' },
        otherField: 'keep',
      },
    });
    const out = scrubEvent(event);
    expect(out.extra).not.toHaveProperty('details');
    expect(out.extra).toHaveProperty('otherField');
  });

  it('removes details from every context object', () => {
    const event = makeEvent({
      contexts: {
        myContext: { details: { userId: 'some-id', secret: 'very-secret' }, keepMe: 'yes' },
        anotherContext: { details: { nested: true }, other: 123 },
      },
    });
    const out = scrubEvent(event);
    expect(out.contexts?.['myContext']).not.toHaveProperty('details');
    expect(out.contexts?.['myContext']).toHaveProperty('keepMe', 'yes');
    expect(out.contexts?.['anotherContext']).not.toHaveProperty('details');
    expect(out.contexts?.['anotherContext']).toHaveProperty('other', 123);
  });

  it('full AppError.validation flow — no email, no token, no details object anywhere', () => {
    // Analogous to AppError.validation('bad email foo@bar.com', { email: 'foo@bar.com', token: 'eyJabc.def.ghi' })
    const event = makeEvent({
      message: 'bad email foo@bar.com',
      exception: {
        values: [
          {
            type: 'AppError',
            value: 'bad email foo@bar.com — token eyJabc.def.ghi',
          },
        ],
      },
      extra: {
        details: { email: 'foo@bar.com', token: 'eyJabc.def.ghi' },
      },
      request: {
        headers: { Authorization: 'Bearer eyJabc.def.ghi', 'content-type': 'application/json' },
      },
    });
    const out = scrubEvent(event);

    // No email anywhere
    const serialised = JSON.stringify(out);
    expect(serialised).not.toContain('foo@bar.com');

    // No JWT token anywhere
    expect(serialised).not.toContain('eyJabc.def.ghi');

    // No details object (no email/token keys)
    expect(out.extra).not.toHaveProperty('details');
    expect(serialised).not.toContain('"email"');
    expect(serialised).not.toContain('"token"');
  });
});

// ---------------------------------------------------------------------------
// Rule 5 — Authorization header dropped; Bearer token stripped from message
// ---------------------------------------------------------------------------

describe('Rule 5 — Authorization / Bearer stripped', () => {
  it('drops Authorization header (mixed case)', () => {
    const event = makeEvent({
      request: {
        headers: { Authorization: 'Bearer eyJabc.def.ghi', 'content-type': 'application/json' },
      },
    });
    const out = scrubEvent(event);
    expect(out.request?.headers).not.toHaveProperty('Authorization');
    expect(out.request?.headers).not.toHaveProperty('authorization');
    expect(out.request?.headers).toHaveProperty('content-type');
  });

  it('redacts Bearer token in message', () => {
    const event = makeEvent({ message: 'token was Bearer eyJabc.def.ghi and failed' });
    const out = scrubEvent(event);
    expect(out.message).not.toContain('eyJabc.def.ghi');
    expect(out.message).toContain('[redacted-token]');
  });

  it('redacts eyJ JWT in message', () => {
    const event = makeEvent({ message: 'got eyJabc.def.ghi as credential' });
    const out = scrubEvent(event);
    expect(out.message).not.toContain('eyJabc.def.ghi');
    expect(out.message).toContain('[redacted-token]');
  });
});

// ---------------------------------------------------------------------------
// Rule 6 — Cookie / Set-Cookie dropped from headers
// ---------------------------------------------------------------------------

describe('Rule 6 — Cookie / Set-Cookie headers dropped', () => {
  it('drops Cookie header', () => {
    const event = makeEvent({
      request: { headers: { Cookie: 'session=abc123; other=val', 'x-request-id': 'req-1' } },
    });
    const out = scrubEvent(event);
    expect(out.request?.headers).not.toHaveProperty('Cookie');
    expect(out.request?.headers).not.toHaveProperty('cookie');
    expect(out.request?.headers).toHaveProperty('x-request-id');
  });

  it('drops Set-Cookie header', () => {
    const event = makeEvent({
      request: { headers: { 'Set-Cookie': 'token=xyz; Path=/; HttpOnly' } },
    });
    const out = scrubEvent(event);
    expect(out.request?.headers).not.toHaveProperty('Set-Cookie');
    expect(out.request?.headers).not.toHaveProperty('set-cookie');
  });
});

// ---------------------------------------------------------------------------
// Rule 7 — No request body
// ---------------------------------------------------------------------------

describe('Rule 7 — request.data (body) deleted', () => {
  it('deletes event.request.data', () => {
    const event = makeEvent({
      request: {
        method: 'POST',
        url: '/api/users',
        data: { password: 'supersecret', email: 'user@test.com' },
      },
    });
    const out = scrubEvent(event);
    expect(out.request).not.toHaveProperty('data');
  });
});

// ---------------------------------------------------------------------------
// Rule 9 — Regex redaction in message and exception values
// ---------------------------------------------------------------------------

describe('Rule 9 — PII regex redaction', () => {
  it('redacts email from message', () => {
    const event = makeEvent({ message: 'user foo@bar.com tried to sign in' });
    const out = scrubEvent(event);
    expect(out.message).not.toContain('foo@bar.com');
    expect(out.message).toContain('[redacted-email]');
  });

  it('redacts Singapore phone number (+65XXXXXXXX)', () => {
    const event = makeEvent({ message: 'OTP sent to +6591234567' });
    const out = scrubEvent(event);
    expect(out.message).not.toContain('+6591234567');
    expect(out.message).toContain('[redacted-phone]');
  });

  it('redacts general E.164 phone number', () => {
    const event = makeEvent({ message: 'number +447911123456 attempted login' });
    const out = scrubEvent(event);
    expect(out.message).not.toContain('+447911123456');
    expect(out.message).toContain('[redacted-phone]');
  });

  it('redacts email from exception value', () => {
    const event = makeEvent({
      exception: {
        values: [{ type: 'ValidationError', value: 'Email user@example.com is invalid' }],
      },
    });
    const out = scrubEvent(event);
    expect(out.exception?.values?.[0]?.value).not.toContain('user@example.com');
    expect(out.exception?.values?.[0]?.value).toContain('[redacted-email]');
  });

  it('redacts JWT from exception value', () => {
    const event = makeEvent({
      exception: {
        values: [
          {
            type: 'Error',
            value: 'invalid token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.SIGNATURE',
          },
        ],
      },
    });
    const out = scrubEvent(event);
    expect(out.exception?.values?.[0]?.value).not.toContain('eyJhbGciOiJIUzI1NiJ9');
    expect(out.exception?.values?.[0]?.value).toContain('[redacted-token]');
  });
});

// ---------------------------------------------------------------------------
// Rule 10 — No client IP
// ---------------------------------------------------------------------------

describe('Rule 10 — ip_address absent', () => {
  it('clears ip_address from user', () => {
    const event = makeEvent({
      user: { id: 'user-cuid2', ip_address: '123.45.67.89', email: 'user@test.com' },
    });
    const out = scrubEvent(event);
    expect(out.user).not.toHaveProperty('ip_address');
  });

  it('user is id-only after scrub', () => {
    const event = makeEvent({
      user: { id: 'abc123', ip_address: '1.2.3.4', email: 'a@b.com', username: 'alice' },
    });
    const out = scrubEvent(event);
    expect(out.user).toEqual({ id: 'abc123' });
  });

  it('user with no id results in empty user object', () => {
    const event = makeEvent({ user: { ip_address: '10.0.0.1', email: 'anon@test.com' } });
    const out = scrubEvent(event);
    expect(out.user).toEqual({});
  });
});

// ---------------------------------------------------------------------------
// Rule 11 — S3 signed-URL fragments redacted
// ---------------------------------------------------------------------------

describe('Rule 11 — S3 signed-URL redaction', () => {
  it('redacts tribely-selfies bucket reference from message', () => {
    const event = makeEvent({
      message: 'failed to load tribely-selfies-prod/abc123/selfie.jpg',
    });
    const out = scrubEvent(event);
    expect(out.message).not.toContain('tribely-selfies-prod');
    expect(out.message).toContain('[redacted-url]');
  });

  it('redacts X-Amz-Signature from message', () => {
    const event = makeEvent({
      message: 'presigned URL X-Amz-Signature=aabbccddeeff1122334455 expired',
    });
    const out = scrubEvent(event);
    expect(out.message).not.toContain('aabbccddeeff1122334455');
    expect(out.message).toContain('[redacted-url]');
  });

  it('redacts X-Amz-Credential from message', () => {
    const event = makeEvent({
      message: 'X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20240101',
    });
    const out = scrubEvent(event);
    expect(out.message).toContain('[redacted-url]');
    expect(out.message).not.toContain('AKIAIOSFODNN7EXAMPLE');
  });

  it('redacts S3 URL from request.url', () => {
    const event = makeEvent({
      request: { url: 'https://s3.amazonaws.com/tribely-selfies-prod/abc?X-Amz-Signature=aabbc' },
    });
    const out = scrubEvent(event);
    expect(out.request?.url).not.toContain('tribely-selfies-prod');
    expect(out.request?.url).not.toContain('X-Amz-Signature');
  });
});

// ---------------------------------------------------------------------------
// Rule 12 — user is { id } only (no email, phone, name)
// ---------------------------------------------------------------------------

describe('Rule 12 — user is id-only', () => {
  it('retains only the id field on the user object', () => {
    const event = makeEvent({
      user: {
        id: 'cuid2abc123',
        email: 'user@example.com',
        phone: '+6591234567',
        username: 'alice',
        ip_address: '10.0.0.1',
      },
    });
    const out = scrubEvent(event);
    expect(out.user).toEqual({ id: 'cuid2abc123' });
  });
});

// ---------------------------------------------------------------------------
// Immutability — scrubEvent must not mutate the input event
// ---------------------------------------------------------------------------

describe('Immutability', () => {
  it('does not mutate the input event', () => {
    const original: ErrorEvent = makeEvent({
      message: 'email user@test.com',
      request: { headers: { Authorization: 'Bearer abc' }, data: { field: 'val' } },
      extra: { details: { a: 1 } },
      user: { id: 'u1', ip_address: '1.2.3.4' },
    });
    const originalJson = JSON.stringify(original);

    scrubEvent(original);

    expect(JSON.stringify(original)).toBe(originalJson);
  });
});

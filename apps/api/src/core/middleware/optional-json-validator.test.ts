import { Hono } from 'hono';
import { describe, expect, it, vi } from 'vitest';
import { z } from 'zod';
import { errorHandler } from './error-handler.js';
import { optionalJsonValidator } from './optional-json-validator.js';

// ---------------------------------------------------------------------------
// Schema fixture — all fields optional to mirror the real use-case shape
// ---------------------------------------------------------------------------

const testSchema = z.object({
  message: z.string().optional(),
  count: z.number().optional(),
});

type TestBody = z.infer<typeof testSchema>;

// ---------------------------------------------------------------------------
// App builder
// ---------------------------------------------------------------------------

/**
 * Builds a minimal Hono app that:
 *  1. Mounts the error handler so AppError → JSON 400.
 *  2. Optionally prepends a prior middleware (for the composition test).
 *  3. Runs `optionalJsonValidator(testSchema)`.
 *  4. Returns 200 with the validated body so tests can assert on its value.
 */
function buildApp(
  priorMiddleware?: (
    c: Parameters<typeof optionalJsonValidator>[0] extends never
      ? never
      : Parameters<ReturnType<typeof optionalJsonValidator>>[0],
    next: () => Promise<void>,
  ) => Promise<void>,
) {
  const app = new Hono();
  app.onError(errorHandler);

  if (priorMiddleware) {
    app.use('*', priorMiddleware);
  }

  app.use('*', optionalJsonValidator(testSchema));

  app.post('/probe', (c) => {
    const body = c.req.valid('json' as never) as TestBody;
    return c.json({ body });
  });

  return app;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('optionalJsonValidator middleware', () => {
  it('TC1: absent body with Content-Type: application/json — resolves to schema default, downstream runs', async () => {
    const app = buildApp();

    const res = await app.request('/probe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      // No body supplied
    });

    expect(res.status).toBe(200);
    const data = (await res.json()) as { body: TestBody };
    // All fields are optional → schema parses {} → returns {}
    expect(data.body).toEqual({});
  });

  it('TC2: empty-string body with Content-Type: application/json — resolves to schema default (Dio wire shape)', async () => {
    const app = buildApp();

    const res = await app.request('/probe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '',
    });

    expect(res.status).toBe(200);
    const data = (await res.json()) as { body: TestBody };
    expect(data.body).toEqual({});
  });

  it('TC3: valid present body — c.req.valid("json") returns the parsed object', async () => {
    const app = buildApp();

    const res = await app.request('/probe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'hello', count: 42 }),
    });

    expect(res.status).toBe(200);
    const data = (await res.json()) as { body: TestBody };
    expect(data.body).toEqual({ message: 'hello', count: 42 });
  });

  it('TC4: present-but-invalid body (wrong field type) — returns 400, handler does NOT run', async () => {
    const handlerSpy = vi.fn();
    const app = new Hono();
    app.onError(errorHandler);
    app.use('*', optionalJsonValidator(testSchema));
    app.post('/probe', (c) => {
      handlerSpy();
      return c.json({ ok: true });
    });

    // `count` must be a number; supply a string to trigger validation failure
    const res = await app.request('/probe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ count: 'not-a-number' }),
    });

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: { code: string; message: string } };
    expect(body.error.code).toBe('VALIDATION_ERROR');
    expect(body.error.message).toBe('Invalid request body');
    expect(handlerSpy).not.toHaveBeenCalled();
  });

  it('TC5: composition — prior middleware calls c.req.json() first, optionalJsonValidator still resolves correctly', async () => {
    // Simulate rateLimitByPhone or any other middleware that pre-reads the body.
    // After the first read Hono caches the parsed body internally; the second
    // read via our `c.req.json().catch(() => ({}))` must still work.
    const priorMiddlewareCalled = vi.fn();

    const priorMiddleware = async (
      c: Parameters<ReturnType<typeof optionalJsonValidator>>[0],
      next: () => Promise<void>,
    ) => {
      // Intentionally consume the body the same way rateLimitByPhone does
      await c.req.json<unknown>().catch(() => ({}));
      priorMiddlewareCalled();
      await next();
    };

    const app = buildApp(priorMiddleware);

    // Send a valid body so we can confirm the parsed value survives both reads
    const res = await app.request('/probe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'composed' }),
    });

    expect(priorMiddlewareCalled).toHaveBeenCalledOnce();
    expect(res.status).toBe(200);
    const data = (await res.json()) as { body: TestBody };
    expect(data.body).toEqual({ message: 'composed' });
  });
});

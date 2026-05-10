import { Hono } from 'hono';
import { describe, expect, it } from 'vitest';
import { getRequestContext } from '../../context/request-context.js';
import { requestContext, type RequestContextVariables } from '../request-context.js';

describe('requestContext middleware', () => {
  const buildApp = () => {
    const app = new Hono<{ Variables: RequestContextVariables }>();
    app.use('*', requestContext());
    app.get('/probe', (c) => {
      const ctx = getRequestContext();
      return c.json({
        var: c.get('requestId'),
        store: ctx?.requestId ?? null,
      });
    });
    return app;
  };

  it('generates a requestId when no header is supplied', async () => {
    const app = buildApp();
    const res = await app.request('/probe');
    const body = (await res.json()) as { var: string; store: string };

    expect(body.var).toMatch(/^[a-z0-9]{8,}$/i);
    expect(body.store).toBe(body.var);
    expect(res.headers.get('X-Request-Id')).toBe(body.var);
  });

  it('reuses the inbound X-Request-Id header', async () => {
    const app = buildApp();
    const res = await app.request('/probe', {
      headers: { 'X-Request-Id': 'caller-supplied-id-123' },
    });
    const body = (await res.json()) as { var: string };

    expect(body.var).toBe('caller-supplied-id-123');
    expect(res.headers.get('X-Request-Id')).toBe('caller-supplied-id-123');
  });

  it('rejects oversized inbound ids and falls back to generated', async () => {
    const app = buildApp();
    const huge = 'x'.repeat(200);
    const res = await app.request('/probe', { headers: { 'X-Request-Id': huge } });
    const body = (await res.json()) as { var: string };

    expect(body.var).not.toBe(huge);
    expect(body.var.length).toBeLessThanOrEqual(128);
  });

  it('frames are independent across concurrent requests', async () => {
    const app = buildApp();
    const [a, b] = await Promise.all([
      app.request('/probe', { headers: { 'X-Request-Id': 'a' } }),
      app.request('/probe', { headers: { 'X-Request-Id': 'b' } }),
    ]);
    const aBody = (await a.json()) as { var: string };
    const bBody = (await b.json()) as { var: string };

    expect(aBody.var).toBe('a');
    expect(bBody.var).toBe('b');
  });
});

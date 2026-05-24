import { Hono } from 'hono';
import { describe, expect, it, vi } from 'vitest';
import { errorHandler } from './error-handler.js';
import type { User } from '@/features/users/domain/entities/user.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { requireAdmin } from './require-admin.js';
import type { AuthVariables } from './require-auth.js';

// ---------------------------------------------------------------------------
// Minimal stub helpers
// ---------------------------------------------------------------------------

function makeUserRepo(user: User | null): UserRepository {
  return {
    findById: vi.fn().mockResolvedValue(user),
  } as unknown as UserRepository;
}

function makeUser(isAdmin: boolean): User {
  return { isAdmin } as unknown as User;
}

/**
 * Builds a minimal Hono app that:
 *  1. Pre-seeds `userId` in the context (simulating requireAuth having run).
 *  2. Runs requireAdmin.
 *  3. Returns 200 on success.
 */
function buildApp(users: UserRepository) {
  const app = new Hono<{ Variables: AuthVariables }>();

  app.onError(errorHandler);

  // Simulate requireAuth pre-seeding userId
  app.use('*', async (c, next) => {
    c.set('userId', 'user-123');
    c.set('email', 'test@example.com');
    await next();
  });

  app.use('*', requireAdmin(users));

  app.get('/probe', (c) => c.json({ ok: true }));

  return app;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('requireAdmin middleware', () => {
  it('throws UNAUTHORIZED when the user does not exist', async () => {
    const users = makeUserRepo(null);
    const app = buildApp(users);

    const res = await app.request('/probe');

    expect(res.status).toBe(401);
    const body = (await res.json()) as { error: { code: string; message: string } };
    expect(body.error.code).toBe('UNAUTHORIZED');
    expect(body.error.message).toBe('User not found');
  });

  it('throws FORBIDDEN when the user exists but is not an admin', async () => {
    const users = makeUserRepo(makeUser(false));
    const app = buildApp(users);

    const res = await app.request('/probe');

    expect(res.status).toBe(403);
    const body = (await res.json()) as { error: { code: string; message: string } };
    expect(body.error.code).toBe('FORBIDDEN');
    expect(body.error.message).toBe('Admin required');
  });

  it('calls next() and returns 200 when the user is an admin', async () => {
    const users = makeUserRepo(makeUser(true));
    const app = buildApp(users);

    const res = await app.request('/probe');

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean };
    expect(body.ok).toBe(true);
  });
});

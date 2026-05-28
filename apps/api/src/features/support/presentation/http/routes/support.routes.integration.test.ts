// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { JwtAccessTokenIssuer } from '@/features/auth/infrastructure/adapters/jwt-access-token-issuer.js';
import { buildApp } from '../../../../../app.js';

const dbUrl = process.env.DATABASE_URL;

describe.skipIf(!dbUrl)('POST /support/tickets (integration)', () => {
  let db: PrismaClient;
  let userToken: string;
  let userId: string;
  const createdTicketIds: string[] = [];

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const tokens = new JwtAccessTokenIssuer();

    userId = createId();

    await db.user.create({
      data: {
        id: userId,
        email: `support-user-${userId}@test.dev`,
        displayName: 'Support Test User',
        emailVerifiedAt: new Date(),
      },
    });

    const issued = await tokens.issue({
      userId,
      email: `support-user-${userId}@test.dev`,
    });
    userToken = issued.value;
  });

  afterAll(async () => {
    if (!dbUrl) return;
    // Cleanup in FK-safe order: outbox rows first, then tickets, then user.
    await db.outboxEvent
      .deleteMany({
        where: { aggregateType: 'SupportTicket', aggregateId: { in: createdTicketIds } },
      })
      .catch(() => null);
    await db.supportTicket
      .deleteMany({ where: { id: { in: createdTicketIds } } })
      .catch(() => null);
    await db.user.deleteMany({ where: { id: userId } }).catch(() => null);
    await db.$disconnect();
  });

  it('returns 401 without Authorization header', async () => {
    const { app } = buildApp();
    const res = await app.request('/support/tickets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ category: 'other', message: 'hello' }),
    });
    expect(res.status).toBe(401);
  });

  it('returns 400 for pure-whitespace message', async () => {
    const { app } = buildApp();
    const res = await app.request('/support/tickets', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${userToken}`,
      },
      body: JSON.stringify({ category: 'other', message: '   ' }),
    });
    expect(res.status).toBe(400);
  });

  it('returns 400 for invalid category', async () => {
    const { app } = buildApp();
    const res = await app.request('/support/tickets', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${userToken}`,
      },
      body: JSON.stringify({ category: 'not_a_real_category', message: 'hello' }),
    });
    expect(res.status).toBe(400);
  });

  it('returns 201 on happy path, persists row + outbox event', async () => {
    const { app } = buildApp();
    const res = await app.request('/support/tickets', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${userToken}`,
      },
      body: JSON.stringify({ category: 'feedback', message: 'Great app, love it!' }),
    });
    expect(res.status).toBe(201);

    const body = (await res.json()) as { ticket: { id: string; createdAt: string } };
    expect(body.ticket.id).toBeTruthy();
    expect(body.ticket.createdAt).toBeTruthy();
    createdTicketIds.push(body.ticket.id);

    // Verify the ticket row was persisted with the email snapshot.
    const row = await db.supportTicket.findUnique({ where: { id: body.ticket.id } });
    expect(row).not.toBeNull();
    expect(row?.userEmailSnapshot).toBe(`support-user-${userId}@test.dev`);

    // Verify the outbox event row was written.
    const outboxRow = await db.outboxEvent.findFirst({
      where: { aggregateType: 'SupportTicket', aggregateId: body.ticket.id },
    });
    expect(outboxRow).not.toBeNull();
    expect(outboxRow?.type).toBe('support.ticketSubmitted');
  });

  it('returns 201 with deep-link payload (reportId present)', async () => {
    const { app } = buildApp();
    const fakeReportId = createId();
    const res = await app.request('/support/tickets', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${userToken}`,
      },
      body: JSON.stringify({
        category: 'report_followup_7d',
        message: 'I reported this 8 days ago and heard nothing.',
        reportId: fakeReportId,
      }),
    });
    expect(res.status).toBe(201);

    const body = (await res.json()) as { ticket: { id: string; createdAt: string } };
    createdTicketIds.push(body.ticket.id);

    // Verify reportId was persisted as free-text (no FK).
    const row = await db.supportTicket.findUnique({ where: { id: body.ticket.id } });
    expect(row?.reportId).toBe(fakeReportId);
  });

  it('returns 422 with support.rateLimited subcode when 6th submission in 24h', async () => {
    const { app } = buildApp();

    // The use case rate-limits at 5 per 24h. We already submitted 2 above —
    // seed 3 more directly so the 6th HTTP call trips the guard.
    const now = new Date();
    const seedIds = [createId(), createId(), createId()];
    await db.supportTicket.createMany({
      data: seedIds.map((id) => ({
        id,
        userId,
        userEmailSnapshot: `support-user-${userId}@test.dev`,
        category: 'other',
        message: 'seed ticket for rate-limit test',
        reportId: null,
        status: 'open',
        createdAt: now,
        resolvedAt: null,
      })),
    });
    createdTicketIds.push(...seedIds);

    // 6th ticket — must be rejected.
    const res = await app.request('/support/tickets', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${userToken}`,
      },
      body: JSON.stringify({ category: 'other', message: 'This is my 6th ticket today.' }),
    });
    expect(res.status).toBe(422);

    const errBody = (await res.json()) as {
      error: { code: string; message: string };
    };
    expect(errBody.error.code).toBe('UNPROCESSABLE');
    expect(errBody.error.message).toBe('support.rateLimited');
  });
});

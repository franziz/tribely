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

describe.skipIf(!dbUrl)('POST /reports (integration)', () => {
  let db: PrismaClient;
  let reporterToken: string;
  let reporterUserId: string;
  let reviewOwnerUserId: string;
  let reviewId: string;
  let eventId: string;
  const createdReportIds: string[] = [];

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    const tokens = new JwtAccessTokenIssuer();

    reporterUserId = createId();
    reviewOwnerUserId = createId();

    await db.user.createMany({
      data: [
        {
          id: reporterUserId,
          email: `reporter-${reporterUserId}@rep.test`,
          displayName: 'Reporter',
          emailVerifiedAt: new Date(),
        },
        {
          id: reviewOwnerUserId,
          email: `review-owner-${reviewOwnerUserId}@rep.test`,
          displayName: 'ReviewOwner',
        },
      ],
    });

    const issued = await tokens.issue({
      userId: reporterUserId,
      email: `reporter-${reporterUserId}@rep.test`,
    });
    reporterToken = issued.value;

    // Seed an event so the review FK is satisfiable.
    eventId = createId();
    const now = new Date();
    await db.event.create({
      data: {
        id: eventId,
        hostUserId: reviewOwnerUserId,
        title: 'Report Integration Test Event',
        venueAddress: '1 Test St',
        venueCity: 'Singapore',
        venueLatitude: 1.3,
        venueLongitude: 103.8,
        startsAt: new Date(now.getTime() - 4 * 60 * 60 * 1000),
        endsAt: new Date(now.getTime() - 2 * 60 * 60 * 1000),
        capacity: 5,
        category: 'food',
        costNotes: null,
        approvalMode: 'manual',
        status: 'completed',
      },
    });

    // Seed a review to be used as the report target.
    reviewId = createId();
    await db.review.create({
      data: {
        id: reviewId,
        eventId,
        raterUserId: reporterUserId,
        ratedUserId: reviewOwnerUserId,
        rating: 3,
        comment: null,
        createdAt: now,
        updatedAt: now,
        hidden: false,
        hiddenAt: null,
        hiddenReason: null,
      },
    });
  });

  afterAll(async () => {
    if (!dbUrl) return;
    // Cleanup in FK-safe order.
    await db.outboxEvent
      .deleteMany({ where: { aggregateType: 'Report', aggregateId: { in: createdReportIds } } })
      .catch(() => null);
    await db.report.deleteMany({ where: { id: { in: createdReportIds } } }).catch(() => null);
    await db.review.deleteMany({ where: { id: reviewId } }).catch(() => null);
    await db.event.deleteMany({ where: { id: eventId } }).catch(() => null);
    await db.user
      .deleteMany({ where: { id: { in: [reporterUserId, reviewOwnerUserId] } } })
      .catch(() => null);
    await db.$disconnect();
  });

  it('returns 401 without Authorization header', async () => {
    const { app } = buildApp();
    const res = await app.request('/reports', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetType: 'review', targetId: reviewId, reason: 'spam' }),
    });
    expect(res.status).toBe(401);
  });

  it('returns 400 for invalid body (missing targetId)', async () => {
    const { app } = buildApp();
    const res = await app.request('/reports', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${reporterToken}`,
      },
      body: JSON.stringify({ targetType: 'review', reason: 'spam' }),
    });
    expect(res.status).toBe(400);
  });

  it('returns 400 for invalid targetType (schema rejects user/event)', async () => {
    const { app } = buildApp();
    const res = await app.request('/reports', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${reporterToken}`,
      },
      body: JSON.stringify({ targetType: 'user', targetId: createId(), reason: 'spam' }),
    });
    // Zod schema only allows literal('review') — anything else is a 400.
    expect(res.status).toBe(400);
  });

  it('returns 404 when target review does not exist', async () => {
    const { app } = buildApp();
    const nonExistentId = createId();
    const res = await app.request('/reports', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${reporterToken}`,
      },
      body: JSON.stringify({ targetType: 'review', targetId: nonExistentId, reason: 'spam' }),
    });
    expect(res.status).toBe(404);
  });

  it('returns 201 and creates the report on happy path', async () => {
    const { app } = buildApp();
    const res = await app.request('/reports', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${reporterToken}`,
      },
      body: JSON.stringify({
        targetType: 'review',
        targetId: reviewId,
        reason: 'spam',
        comment: 'This review is clearly spam',
      }),
    });
    expect(res.status).toBe(201);
    const body = (await res.json()) as { report: { id: string; targetType: string } };
    expect(body.report.id).toBeTruthy();
    expect(body.report.targetType).toBe('review');
    createdReportIds.push(body.report.id);

    // Verify outbox event was published.
    const outboxRow = await db.outboxEvent.findFirst({
      where: { aggregateType: 'Report', aggregateId: body.report.id },
    });
    expect(outboxRow).not.toBeNull();
    expect(outboxRow?.type).toBe('reports.reportFiled');
  });
});

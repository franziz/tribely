// Vitest does not auto-load .env (CLAUDE.md gotcha) — `dotenv/config` must
// run before any read of process.env below.
import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { createId } from '@paralleldrive/cuid2';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { PrismaUnitOfWork } from '@/core/db/prisma-unit-of-work.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';

import { HashedPassword } from '../../domain/value-objects/hashed-password.js';
import { Credential } from '../../domain/entities/credential.js';
import { CredentialPrismaRepository } from './credential.prisma-repository.js';

const dbUrl = process.env.DATABASE_URL;

/**
 * Integration tests for CredentialPrismaRepository.deleteForUser against the
 * real Postgres DB. Skipped when DATABASE_URL is unset.
 *
 * Brief C acceptance: after deleteForUser, the credential row for user X is
 * absent; rows for Y and Z are untouched.
 */
describe.skipIf(!dbUrl)('CredentialPrismaRepository.deleteForUser (integration)', () => {
  let db: PrismaClient;
  let unitOfWork: UnitOfWork;
  let repo: CredentialPrismaRepository;

  // Three isolated user IDs — seeded in beforeAll, torn down in afterAll.
  let userX: string;
  let userY: string;
  let userZ: string;

  const makeCredential = (userId: string): Credential =>
    Credential.rehydrate({
      userId,
      passwordHash: HashedPassword.fromHash('argon2:test-hash'),
      passwordSetAt: new Date('2026-01-01T00:00:00Z'),
      lastSignedInAt: null,
    });

  const saveCredential = async (credential: Credential): Promise<void> => {
    await unitOfWork.run(async (ctx) => {
      await repo.save(credential, ctx);
    });
  };

  beforeAll(async () => {
    if (!dbUrl) return;
    db = new PrismaClient({ adapter: new PrismaPg({ connectionString: dbUrl }) });
    unitOfWork = new PrismaUnitOfWork(db);
    repo = new CredentialPrismaRepository(db);

    userX = createId();
    userY = createId();
    userZ = createId();

    await db.user.createMany({
      data: [
        { id: userX, email: `cred-x-${userX}@tri134c.test`, displayName: 'TRI-134C User X' },
        { id: userY, email: `cred-y-${userY}@tri134c.test`, displayName: 'TRI-134C User Y' },
        { id: userZ, email: `cred-z-${userZ}@tri134c.test`, displayName: 'TRI-134C User Z' },
      ],
    });

    // Persist one credential per user.
    await saveCredential(makeCredential(userX));
    await saveCredential(makeCredential(userY));
    await saveCredential(makeCredential(userZ));
  });

  afterAll(async () => {
    if (!dbUrl) return;
    // Best-effort cleanup — credential rows cascade-deleted when user is deleted.
    await db.credential
      .deleteMany({
        where: { userId: { in: [userX, userY, userZ] } },
      })
      .catch(() => null);
    await db.user.deleteMany({ where: { id: { in: [userX, userY, userZ] } } }).catch(() => null);
    await db.$disconnect();
  });

  it('removes the credential row for user X', async () => {
    await unitOfWork.run(async (ctx) => {
      await repo.deleteForUser(userX, ctx);
    });

    const row = await db.credential.findUnique({ where: { userId: userX } });
    expect(row).toBeNull();
  });

  it('leaves credentials for users Y and Z untouched', async () => {
    const rowY = await db.credential.findUnique({ where: { userId: userY } });
    const rowZ = await db.credential.findUnique({ where: { userId: userZ } });

    expect(rowY).not.toBeNull();
    expect(rowZ).not.toBeNull();
  });
});

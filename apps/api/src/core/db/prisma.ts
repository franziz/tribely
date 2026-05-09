import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';
import { env } from '../config/env.js';

/**
 * Prisma 7+ requires a driver adapter for runtime connections — the `url`
 * is no longer read from schema.prisma at runtime. We use `@prisma/adapter-pg`
 * which wraps the standard `pg` driver.
 *
 * For migrations and `prisma studio`, the URL is read from `prisma.config.ts`
 * (which loads it from the same `DATABASE_URL` env var).
 */
const adapter = new PrismaPg({ connectionString: env.DATABASE_URL });

export const prisma = new PrismaClient({
  adapter,
  log: env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
});

export type Db = typeof prisma;

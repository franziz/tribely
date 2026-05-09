import 'dotenv/config';
import { defineConfig, env } from 'prisma/config';

type Env = {
  DATABASE_URL: string;
};

/**
 * Prisma 7+ moved the datasource URL out of `schema.prisma` and into this
 * config file. `prisma migrate` and `prisma studio` read this to connect.
 *
 * The runtime `PrismaClient` does NOT use this — it connects via the
 * `@prisma/adapter-pg` driver adapter (see `src/core/db/prisma.ts`).
 */
export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: env<Env>('DATABASE_URL'),
  },
});

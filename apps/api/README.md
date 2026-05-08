# @tribely/api

Hono + Prisma backend.

## Scripts (run from this directory or via root workspace)

```bash
npm run dev          # tsx watch
npm run build        # tsc
npm run start        # node dist/index.js

npm run db:generate         # prisma generate
npm run db:migrate          # prisma migrate dev (applies all pending; prompts for name on schema drift)
npm run db:migrate:create   # prisma migrate dev --create-only (generate SQL without applying)
npm run db:migrate:deploy   # prisma migrate deploy (production)
npm run db:studio           # browse data

npm run typecheck
npm run test
```

From the repo root, prefix with `api:` — e.g. `npm run api:dev`, `npm run api:db:migrate`.

## Endpoints

- `GET /health`
- `POST /auth/sign-up` — body `{ email, password (min 8), displayName }`
- `POST /auth/sign-in` — body `{ email, password }`
- `GET /users/:id`

Responses use a uniform error shape: `{ "error": { "code", "message", "details?" } }`.

## Adding a feature

Use `/api-new-feature <name>`. See the project skills under `.claude/skills/` and the architecture conventions in the root `CLAUDE.md`.

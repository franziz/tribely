# @tribely/api

Hono + Prisma backend.

## Scripts

```bash
pnpm dev          # tsx watch
pnpm build        # tsc
pnpm start        # node dist/index.js

pnpm db:generate  # prisma generate
pnpm db:migrate   # prisma migrate dev
pnpm db:studio    # browse data

pnpm typecheck
pnpm test
```

## Endpoints

- `GET /health`
- `POST /auth/sign-up` — body `{ email, password (min 8), displayName }`
- `POST /auth/sign-in` — body `{ email, password }`

Responses use a uniform error shape: `{ "error": { "code", "message", "details?" } }`.

## Adding a feature

Mirror the `auth/` folder structure. Wire your new use cases into `core/di/container.ts` and mount your routes in `app.ts`.

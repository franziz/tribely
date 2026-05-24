# Build context: REPO ROOT (not apps/api/).
# npm workspaces hoist node_modules here; both stages copy from apps/api/... paths.

# ─── Stage 1: builder ────────────────────────────────────────────────────────
FROM node:22-alpine AS builder

WORKDIR /app

# Copy workspace manifests and root tsconfig files first for layer caching.
COPY package.json package-lock.json tsconfig.base.json ./
COPY apps/api/package.json apps/api/

# Install all workspace deps (workspace-aware; resolves hoisted + scoped packages).
RUN npm ci

# Copy API source.
COPY apps/api/ apps/api/

# Generate Prisma client — must run before tsc because @prisma/client types are imported.
# DATABASE_URL is required by prisma.config.ts at module-load time (Prisma 7 config API);
# the value is a placeholder — prisma generate only reads the schema, never connects to the DB.
RUN DATABASE_URL=postgresql://placeholder:placeholder@localhost:5432/placeholder \
    npm run db:generate --workspace=@tribely/api

# Compile TypeScript to dist/.
RUN npm run build --workspace=@tribely/api

# ─── Stage 1b: deps (production only) ────────────────────────────────────────
# Install a clean production-only node_modules so the runtime stage doesn't
# carry TypeScript, Vitest, ESLint, tsx, and other dev tooling (~500MB savings).
FROM node:22-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/

RUN npm ci --omit=dev

# Copy the generated Prisma client from builder on top of the lean install.
# prisma generate writes to the hoisted root node_modules/@prisma/client and
# node_modules/.prisma — we need the builder's generated artifacts, not a
# freshly-installed stub.
COPY --from=builder /app/node_modules/@prisma/client/ node_modules/@prisma/client/
COPY --from=builder /app/node_modules/.prisma/        node_modules/.prisma/

# ─── Stage 2: runtime ────────────────────────────────────────────────────────
FROM node:22-alpine AS runtime

WORKDIR /app

# Production deps (no dev tooling) + pre-generated Prisma client.
COPY --from=deps    /app/node_modules/         node_modules/
COPY --from=builder /app/package.json          package.json
COPY --from=builder /app/apps/api/package.json apps/api/
COPY --from=builder /app/apps/api/dist/        apps/api/dist/
COPY --from=builder /app/apps/api/prisma/      apps/api/prisma/

# Run as non-root for least-privilege.
USER node

# Documentary; Cloud Run overrides the port via the PORT env var at runtime.
EXPOSE 3000

CMD ["node", "apps/api/dist/index.js"]

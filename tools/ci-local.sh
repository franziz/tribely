#!/usr/bin/env bash
# tools/ci-local.sh — local-parity CI runner.
#
# Spins a Dockerized environment that runs the SAME npm gate scripts as the
# GitHub workflows (_api.yml + _mobile.yml), against a faithful CI environment
# (Linux + pinned toolchain + restricted Postgres role), serially.
#
# Usage:
#   npm run ci:local          — via root package.json script
#   bash tools/ci-local.sh   — directly
#
# Requirements: Docker with Compose V2 (`docker compose` not `docker-compose`).
# No real secrets required — default loop uses transport=log placeholders.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.ci.yml"

# ---------------------------------------------------------------------------
# Read toolchain versions from their single sources of truth.
# ---------------------------------------------------------------------------

# SOT: .nvmrc (major version, e.g. "22")
NVMRC="${REPO_ROOT}/.nvmrc"
if [[ -f "${NVMRC}" ]]; then
  NODE_VERSION="$(tr -d '[:space:]' < "${NVMRC}")"
else
  echo "WARNING: .nvmrc not found — falling back to NODE_VERSION=22" >&2
  NODE_VERSION="22"
fi

# SOT: apps/mobile/pubspec.yaml `environment.flutter`
PUBSPEC="${REPO_ROOT}/apps/mobile/pubspec.yaml"
if [[ -f "${PUBSPEC}" ]]; then
  FLUTTER_VERSION="$(grep -E '^\s+flutter:' "${PUBSPEC}" | head -1 | sed 's/.*flutter:[[:space:]]*//' | tr -d '[:space:]')"
else
  echo "WARNING: apps/mobile/pubspec.yaml not found — falling back to FLUTTER_VERSION=3.41.9" >&2
  FLUTTER_VERSION="3.41.9"
fi

echo "ci:local — NODE_VERSION=${NODE_VERSION}  FLUTTER_VERSION=${FLUTTER_VERSION}"

export NODE_VERSION FLUTTER_VERSION

# ---------------------------------------------------------------------------
# Teardown trap — runs even on failure so volumes are cleaned and containers
# do not accumulate across repeated local runs.
# ---------------------------------------------------------------------------
teardown() {
  echo ""
  echo "ci:local — tearing down..."
  docker compose -f "${COMPOSE_FILE}" down -v --remove-orphans 2>/dev/null || true
}
trap teardown EXIT

# ---------------------------------------------------------------------------
# Helper: run a single command inside a service, propagating its exit code.
# We use `docker compose run --rm` (not `up`) so each step runs serially and
# the runner exits with the command's exact exit code.
# ---------------------------------------------------------------------------
compose_run() {
  local service="$1"
  shift
  docker compose -f "${COMPOSE_FILE}" run --rm "${service}" "$@"
}

# ---------------------------------------------------------------------------
# Build images (no-op if already cached; forces a rebuild if Dockerfiles
# or build args changed).
# ---------------------------------------------------------------------------
echo ""
echo "=== ci:local: building images ==="
docker compose -f "${COMPOSE_FILE}" build api-gates mobile-gates

# ---------------------------------------------------------------------------
# Start postgres in the background so it can complete its healthcheck while
# we do nothing yet. api-gates `depends_on: postgres: condition: service_healthy`
# ensures the DB is ready before any api step runs.
# ---------------------------------------------------------------------------
echo ""
echo "=== ci:local: starting postgres ==="
docker compose -f "${COMPOSE_FILE}" up -d postgres

echo "ci:local — waiting for postgres healthcheck..."
# Poll via `docker inspect` until health status is 'healthy'.
# Mirrors CI's retries: 10 x 5s = 50s; we allow up to 120s (24 x 5s).
POSTGRES_CONTAINER="$(docker compose -f "${COMPOSE_FILE}" ps -q postgres 2>/dev/null | head -1)"
attempts=0
max_attempts=24
until [[ "$(docker inspect --format='{{.State.Health.Status}}' "${POSTGRES_CONTAINER}" 2>/dev/null)" == "healthy" ]]; do
  attempts=$((attempts + 1))
  if [[ ${attempts} -ge ${max_attempts} ]]; then
    echo "ERROR: postgres did not become healthy within $((max_attempts * 5))s" >&2
    exit 1
  fi
  sleep 5
  # Re-read container ID in case compose assigned it after initial `up -d`.
  POSTGRES_CONTAINER="$(docker compose -f "${COMPOSE_FILE}" ps -q postgres 2>/dev/null | head -1)"
done
echo "ci:local — postgres healthy."

# ---------------------------------------------------------------------------
# API gates — serial, mirror _api.yml step order exactly.
# All commands call the npm scripts; gate logic lives in the scripts, not here.
# ---------------------------------------------------------------------------
echo ""
echo "=== ci:local: api-gates ==="

echo "--- api: npm ci ---"
compose_run api-gates bash -c "npm ci"

echo "--- api: db:generate (prisma generate) ---"
compose_run api-gates bash -c "DATABASE_URL=postgres://placeholder:placeholder@postgres:5432/placeholder npm run --workspace=@tribely/api db:generate"

echo "--- api: db:migrate:deploy ---"
compose_run api-gates bash -c "DATABASE_URL=postgresql://postgres:postgres@postgres:5432/tribely_test?schema=public npm run --workspace=@tribely/api db:migrate:deploy"

echo "--- api: db:roles:bootstrap ---"
compose_run api-gates bash -c "ADMIN_DATABASE_URL=postgresql://postgres:postgres@postgres:5432/tribely_test?schema=public RUNTIME_DB_PASSWORD=ci_runtime_pw npm run --workspace=@tribely/api db:roles:bootstrap"

echo "--- api: format:check ---"
compose_run api-gates bash -c "npm run --workspace=@tribely/api format:check"

echo "--- api: typecheck ---"
compose_run api-gates bash -c "npm run --workspace=@tribely/api typecheck"

echo "--- api: lint ---"
compose_run api-gates bash -c "npm run --workspace=@tribely/api lint"

echo "--- api: test:coverage ---"
compose_run api-gates bash -c "NODE_ENV=test JWT_SECRET=ci-placeholder-secret-must-be-at-least-32-chars PHONE_HASH_SALT=test_phone_hash_salt_at_least_32_chars_long DATABASE_URL=postgresql://tribely_app:ci_runtime_pw@postgres:5432/tribely_test?schema=public npm run --workspace=@tribely/api test:coverage"

# ---------------------------------------------------------------------------
# Mobile gates — serial, mirror _mobile.yml step order exactly.
# ---------------------------------------------------------------------------
echo ""
echo "=== ci:local: mobile-gates ==="

echo "--- mobile: flutter pub get ---"
compose_run mobile-gates bash -c "cd apps/mobile && flutter pub get"

echo "--- mobile: build_runner codegen ---"
compose_run mobile-gates bash -c "cd apps/mobile && dart run build_runner build --delete-conflicting-outputs"

echo "--- mobile: format:check ---"
compose_run mobile-gates bash -c "npm run mobile:format:check"

echo "--- mobile: analyze ---"
compose_run mobile-gates bash -c "npm run mobile:analyze"

echo "--- mobile: test:coverage ---"
compose_run mobile-gates bash -c "npm run mobile:test:coverage"

# ---------------------------------------------------------------------------
# All gates passed.
# ---------------------------------------------------------------------------
echo ""
echo "=== ci:local: ALL GATES PASSED ==="

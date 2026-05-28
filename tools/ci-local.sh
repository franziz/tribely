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
#
# Optional env vars:
#   CI_LOCAL_PRUNE_IMAGES=1   — teardown also removes the two built runner images
#                               (api-gates, mobile-gates) to fully reclaim disk
#                               space. Default (unset) keeps images cached for
#                               fast reruns.
#
# Design notes on control flow:
#   • `set -e` is intentionally ABSENT. Each step's exit code is captured by
#     run_step() into parallel result arrays rather than aborting the script.
#     `set -u` and `set -o pipefail` are kept for unbound-var and pipe safety.
#   • Per-stack "abort flag" (api_aborted / mobile_aborted): if a PREREQUISITE
#     step fails, the flag is set to 1 and all remaining steps in THAT stack are
#     recorded as SKIPPED without being executed. The other stack is unaffected —
#     the two stacks are independent; a broken api dep does not skip mobile.
#   • GATES within a stack run regardless of other gates' outcomes — a failing
#     gate records FAIL but does not set the abort flag.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.ci.yml"

# ---------------------------------------------------------------------------
# Read toolchain versions from their single sources of truth.
# ---------------------------------------------------------------------------

NVMRC="${REPO_ROOT}/.nvmrc"
if [[ -f "${NVMRC}" ]]; then
  NODE_VERSION="$(tr -d '[:space:]' < "${NVMRC}")"
else
  echo "WARNING: .nvmrc not found — falling back to NODE_VERSION=22" >&2
  NODE_VERSION="22"
fi

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
# Result tracking — three parallel arrays preserve declaration order.
# Each entry is written exactly once per step.
#   step_stacks[]  — "api" or "mobile"
#   step_labels[]  — human-readable label for the report table
#   step_results[] — "PASS" | "FAIL" | "SKIPPED"
# ---------------------------------------------------------------------------
step_stacks=()
step_labels=()
step_results=()

# Per-stack abort flags. Set to 1 when a PREREQUISITE in that stack fails.
api_aborted=0
mobile_aborted=0

# ---------------------------------------------------------------------------
# run_step <stack> <kind> <label> <service> <cmd...>
#
#   stack  — "api" or "mobile"
#   kind   — "prereq" or "gate"
#   label  — display string used in the report (≤20 chars for clean alignment)
#   service — docker compose service name (e.g. "api-gates")
#   cmd... — command passed to `docker compose run --rm <service>`
#
# Behaviour:
#   1. If the stack's abort flag is set, record SKIPPED and return immediately.
#   2. Otherwise execute the command via compose_run.
#   3. On success: record PASS.
#   4. On failure:
#      - always record FAIL.
#      - if kind=prereq, set the stack's abort flag so remaining steps are skipped.
# ---------------------------------------------------------------------------
run_step() {
  local stack="$1"
  local kind="$2"
  local label="$3"
  local service="$4"
  shift 4

  step_stacks+=("${stack}")
  step_labels+=("${label}")

  # Check abort flag for this stack.
  local abort_flag_var="${stack}_aborted"
  if [[ "${!abort_flag_var}" -eq 1 ]]; then
    step_results+=("SKIPPED")
    echo ""
    echo "--- ${stack}: ${label} [SKIPPED — prerequisite failed] ---"
    return
  fi

  echo ""
  echo "--- ${stack}: ${label} ---"
  # Run the step; do NOT let a non-zero exit bubble up (no set -e).
  local exit_code=0
  compose_run "${service}" "$@" || exit_code=$?

  if [[ ${exit_code} -eq 0 ]]; then
    step_results+=("PASS")
  else
    step_results+=("FAIL")
    # A failing prerequisite poisons the rest of this stack.
    if [[ "${kind}" == "prereq" ]]; then
      printf -v "${abort_flag_var}" '%s' "1"
      echo "ci:local — PREREQUISITE '${label}' failed; skipping remaining ${stack} steps." >&2
    fi
  fi
}

# ---------------------------------------------------------------------------
# compose_run <service> <cmd...>
# ---------------------------------------------------------------------------
compose_run() {
  local service="$1"
  shift
  docker compose -f "${COMPOSE_FILE}" run --rm "${service}" "$@"
}

# ---------------------------------------------------------------------------
# Teardown trap — runs unconditionally on EXIT (success, failure, or signal).
# Removes containers + volumes always.
# With CI_LOCAL_PRUNE_IMAGES=1, also removes the two built runner images.
# ---------------------------------------------------------------------------
teardown() {
  echo ""
  echo "ci:local — tearing down (containers + volumes)..."
  docker compose -f "${COMPOSE_FILE}" down -v --remove-orphans 2>/dev/null || true

  if [[ "${CI_LOCAL_PRUNE_IMAGES:-0}" == "1" ]]; then
    echo "ci:local — CI_LOCAL_PRUNE_IMAGES=1: removing built runner images (api-gates, mobile-gates)..."
    docker compose -f "${COMPOSE_FILE}" down --rmi local 2>/dev/null || true
    echo "ci:local — runner images removed."
  else
    echo "ci:local — runner images retained (set CI_LOCAL_PRUNE_IMAGES=1 to remove them)."
  fi
}
trap teardown EXIT

# ---------------------------------------------------------------------------
# Build images (no-op if already cached; forces a rebuild on Dockerfile changes).
# ---------------------------------------------------------------------------
echo ""
echo "=== ci:local: building images ==="
docker compose -f "${COMPOSE_FILE}" build api-gates mobile-gates

# ---------------------------------------------------------------------------
# Start postgres; wait for healthcheck before any api step runs.
# ---------------------------------------------------------------------------
echo ""
echo "=== ci:local: starting postgres ==="
docker compose -f "${COMPOSE_FILE}" up -d postgres

echo "ci:local — waiting for postgres healthcheck..."
POSTGRES_CONTAINER="$(docker compose -f "${COMPOSE_FILE}" ps -q postgres 2>/dev/null | head -1)"
attempts=0
max_attempts=24
until [[ "$(docker inspect --format='{{.State.Health.Status}}' "${POSTGRES_CONTAINER}" 2>/dev/null)" == "healthy" ]]; do
  attempts=$((attempts + 1))
  if [[ ${attempts} -ge ${max_attempts} ]]; then
    echo "ERROR: postgres did not become healthy within $((max_attempts * 5))s" >&2
    # Record a synthetic failure so the report reflects what happened.
    step_stacks+=("api")
    step_labels+=("postgres-healthcheck")
    step_results+=("FAIL")
    api_aborted=1
    break
  fi
  sleep 5
  POSTGRES_CONTAINER="$(docker compose -f "${COMPOSE_FILE}" ps -q postgres 2>/dev/null | head -1)"
done
if [[ ${attempts} -lt ${max_attempts} ]]; then
  echo "ci:local — postgres healthy."
fi

# ---------------------------------------------------------------------------
# API stack
# ---------------------------------------------------------------------------
echo ""
echo "=== ci:local: api gates ==="

run_step api prereq "npm ci" api-gates \
  bash -c "npm ci"

run_step api prereq "db:generate" api-gates \
  bash -c "DATABASE_URL=postgres://placeholder:placeholder@postgres:5432/placeholder npm run --workspace=@tribely/api db:generate"

run_step api prereq "migrate:deploy" api-gates \
  bash -c "DATABASE_URL=postgresql://postgres:postgres@postgres:5432/tribely_test?schema=public npm run --workspace=@tribely/api db:migrate:deploy"

run_step api prereq "roles:bootstrap" api-gates \
  bash -c "ADMIN_DATABASE_URL=postgresql://postgres:postgres@postgres:5432/tribely_test?schema=public RUNTIME_DB_PASSWORD=ci_runtime_pw npm run --workspace=@tribely/api db:roles:bootstrap"

run_step api gate "format:check" api-gates \
  bash -c "npm run --workspace=@tribely/api format:check"

run_step api gate "typecheck" api-gates \
  bash -c "npm run --workspace=@tribely/api typecheck"

run_step api gate "lint" api-gates \
  bash -c "npm run --workspace=@tribely/api lint"

run_step api gate "test:coverage" api-gates \
  bash -c "NODE_ENV=test JWT_SECRET=ci-placeholder-secret-must-be-at-least-32-chars PHONE_HASH_SALT=test_phone_hash_salt_at_least_32_chars_long DATABASE_URL=postgresql://tribely_app:ci_runtime_pw@postgres:5432/tribely_test?schema=public npm run --workspace=@tribely/api test:coverage"

# ---------------------------------------------------------------------------
# Mobile stack (independent of api stack — runs regardless of api_aborted).
# ---------------------------------------------------------------------------
echo ""
echo "=== ci:local: mobile gates ==="

run_step mobile prereq "pub get" mobile-gates \
  bash -c "cd apps/mobile && flutter pub get"

run_step mobile prereq "build_runner" mobile-gates \
  bash -c "cd apps/mobile && dart run build_runner build --delete-conflicting-outputs"

run_step mobile gate "format:check" mobile-gates \
  bash -c "npm run mobile:format:check"

run_step mobile gate "analyze" mobile-gates \
  bash -c "npm run mobile:analyze"

run_step mobile gate "test:coverage" mobile-gates \
  bash -c "npm run mobile:test:coverage"

# ---------------------------------------------------------------------------
# Summary report
# ---------------------------------------------------------------------------
echo ""
echo "===================== ci:local report ====================="
printf "%-8s  %-20s  %s\n" "STACK" "STEP" "RESULT"
echo "-----------------------------------------------------------"

failed_steps=()
skipped_steps=()

for i in "${!step_labels[@]}"; do
  stack="${step_stacks[$i]}"
  label="${step_labels[$i]}"
  result="${step_results[$i]}"
  printf "%-8s  %-20s  %s\n" "${stack}" "${label}" "${result}"
  if [[ "${result}" == "FAIL" ]]; then
    failed_steps+=("${stack} ${label}")
  elif [[ "${result}" == "SKIPPED" ]]; then
    skipped_steps+=("${stack} ${label}")
  fi
done

echo "==========================================================="

# Compute final verdict.
exit_code=0
if [[ ${#failed_steps[@]} -gt 0 || ${#skipped_steps[@]} -gt 0 ]]; then
  exit_code=1
  verdict_parts=()
  if [[ ${#failed_steps[@]} -gt 0 ]]; then
    # Build a comma-separated list of failed step names.
    failed_list=""
    for s in "${failed_steps[@]}"; do
      failed_list="${failed_list:+${failed_list}, }${s}"
    done
    verdict_parts+=("${#failed_steps[@]} failed (${failed_list})")
  fi
  if [[ ${#skipped_steps[@]} -gt 0 ]]; then
    verdict_parts+=("${#skipped_steps[@]} skipped due to prerequisite failure")
  fi
  # Join verdict parts with "; ".
  verdict_msg=""
  for part in "${verdict_parts[@]}"; do
    verdict_msg="${verdict_msg:+${verdict_msg}; }${part}"
  done
  echo "Result: FAILED — ${verdict_msg}"
else
  echo "Result: PASSED"
fi
echo ""

exit ${exit_code}

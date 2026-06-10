#!/usr/bin/env bash
set -euo pipefail

# upload_api_sourcemaps <docker-tag>
#
# Uploads the API source maps produced by the TypeScript compiler to Sentry so
# that production stack traces resolve to the original .ts file + line.
#
# Behaviour:
#   - No-op (exit 0) when SENTRY_AUTH_TOKEN is unset or empty — token-less
#     builds are byte-for-byte unchanged.
#   - If the token IS set but sentry-cli is not on PATH, prints a warning and
#     returns without failing the build (best-effort).
#   - Otherwise: builds the API to produce dist/ + .js.map on the host (upload
#     feed only; the Docker image is unchanged), then injects source-map
#     references, creates/finalises the Sentry release, and uploads the maps.
#
# Required env vars (all optional — upload is skipped when any is absent):
#   SENTRY_AUTH_TOKEN — Sentry internal integration token
#   SENTRY_ORG       — Sentry organisation slug
#   SENTRY_PROJECT   — Sentry project slug

upload_api_sourcemaps() {
  local tag="$1"
  local release="tribely-api@${tag}"

  # Guard: token absent → silent no-op
  if [[ -z "${SENTRY_AUTH_TOKEN:-}" ]]; then
    return 0
  fi

  # Guard: org / project absent → skip with notice
  if [[ -z "${SENTRY_ORG:-}" || -z "${SENTRY_PROJECT:-}" ]]; then
    echo "sentry: SENTRY_ORG or SENTRY_PROJECT not set, skipping source-map upload." >&2
    return 0
  fi

  # Guard: sentry-cli not installed → warn, do not fail
  if ! command -v sentry-cli >/dev/null 2>&1; then
    echo "sentry-cli not installed, skipping upload" >&2
    return 0
  fi

  echo "Building API to produce source maps for release ${release} …"
  npm run --workspace=@tribely/api build

  echo "Injecting source-map references …"
  sentry-cli sourcemap inject ./apps/api/dist

  echo "Creating Sentry release ${release} …"
  sentry-cli releases create "${release}" --finalize

  echo "Uploading source maps …"
  sentry-cli sourcemap upload ./apps/api/dist --release "${release}"

  echo "Sentry source-map upload complete for ${release}."
}

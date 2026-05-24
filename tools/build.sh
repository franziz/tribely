#!/usr/bin/env bash
set -euo pipefail

# Resolve repo root
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || (cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd))"

# Paths
CONFIG_FILE="${CONFIG_FILE:-${repo_root}/tools/config.yml}"
LIB_DIR="${repo_root}/tools/scripts/lib"

# Load libraries
# shellcheck source=/dev/null
source "${LIB_DIR}/config.sh"
# shellcheck source=/dev/null
source "${LIB_DIR}/docker_hub.sh"

# Requirements
require_tools_for_config

# Read basic config
IMAGE="$(cfg_get_image "${CONFIG_FILE}")"
if [[ -z "${IMAGE}" || "${IMAGE}" == "null" ]]; then
  echo "Error: image is not set in ${CONFIG_FILE} (use 'image:' or 'Image:')." >&2
  exit 1
fi

PLATFORMS="$(cfg_get_str "${CONFIG_FILE}" '.platforms' 'linux/amd64,linux/arm64')"
BUILD_CTX="$(cfg_get_str "${CONFIG_FILE}" '.context' "${repo_root}")"
DOCKERFILE_PATH="$(cfg_get_str "${CONFIG_FILE}" '.dockerfile' '')"

# Ask build type (free text)
BUILD_TYPE="${1:-}"
if [[ -z "${BUILD_TYPE}" ]]; then
  read -r -p "Enter build type (e.g., uat, prd, other): " BUILD_TYPE
  BUILD_TYPE="${BUILD_TYPE//[[:space:]]/}"
fi
if [[ -z "${BUILD_TYPE}" ]]; then
  echo "Error: build type cannot be empty." >&2
  exit 1
fi

# Separator (default '.')
SEP="${TAG_SEP:-.}"

# Docker Hub lookup: suggest next number
hub_parse_image "${IMAGE}"
require_tools_for_hub
SUGGESTED_NUM="$(hub_suggest_next_number "${REGISTRY}" "${NAMESPACE}" "${REPO}" "${BUILD_TYPE}" "${SEP}")"

echo "Latest suggestion for ${BUILD_TYPE}${SEP}<n> -> next number: ${SUGGESTED_NUM}"
read -r -p "Next build number [${SUGGESTED_NUM}]: " NEXT_NUM
NEXT_NUM="${NEXT_NUM//[[:space:]]/}"
[[ -z "${NEXT_NUM}" ]] && NEXT_NUM="${SUGGESTED_NUM}"
if ! [[ "${NEXT_NUM}" =~ ^[0-9]+$ ]]; then
  echo "Error: build number must be an integer." >&2
  exit 1
fi

TAG="${BUILD_TYPE}${SEP}${NEXT_NUM}"

# Build args for the chosen env (compatible with Bash 3.x, no 'lastpipe')
BUILD_ARGS=()
while IFS='=' read -r k v; do
  [[ -n "${k}" ]] && BUILD_ARGS+=(--build-arg "${k}=${v}")
done < <(cfg_get_build_args_for_env "${CONFIG_FILE}" "${BUILD_TYPE}" || true)

echo "Repo root: ${repo_root}"
echo "Config:    ${CONFIG_FILE}"
echo "Image:     ${IMAGE}"
echo "Tag:       ${TAG}"
echo "Platforms: ${PLATFORMS}"
if ((${#BUILD_ARGS[@]})); then
  echo "Build args:"
  for pair in "${BUILD_ARGS[@]}"; do
    echo " - ${pair/--build-arg /}"
  done
else
  echo "Build args: (none)"
fi

# Compose docker buildx command
cmd=(docker buildx build
  --platform "${PLATFORMS}"
  -t "${IMAGE}:${TAG}"
  --push
)

[[ -n "${DOCKERFILE_PATH}" && "${DOCKERFILE_PATH}" != "null" ]] && cmd+=( -f "${DOCKERFILE_PATH}" )
((${#BUILD_ARGS[@]})) && cmd+=( "${BUILD_ARGS[@]}" )

# Execute
"${cmd[@]}" "${BUILD_CTX}"

echo "Done. Pushed:"
echo " - ${IMAGE}:${TAG}"

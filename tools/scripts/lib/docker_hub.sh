#!/usr/bin/env bash
set -euo pipefail

require_tools_for_hub() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: 'curl' is required for Docker Hub lookup." >&2
    exit 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: 'jq' is required for Docker Hub lookup." >&2
    exit 1
  fi
}

# Parse image jadi REGISTRY/NAMESPACE/REPO. Default registry docker.io
hub_parse_image() {
  local img="$1"
  local p1 p2 p3
  IFS='/' read -r p1 p2 p3 <<<"$img"
  if [[ -n "${p3:-}" ]]; then
    REGISTRY="$p1"; NAMESPACE="$p2"; REPO="$p3"
  else
    REGISTRY="docker.io"; NAMESPACE="$p1"; REPO="$p2"
  fi
}

hub_fetch_all_tag_names() {
  local ns="$1" repo="$2"
  local url="https://hub.docker.com/v2/repositories/${ns}/${repo}/tags?page_size=100"
  while [[ -n "$url" ]]; do
    local json
    json="$(curl -fsSL "$url")" || return 1
    jq -r '.results[].name' <<<"$json"
    url="$(jq -r '.next // empty' <<<"$json")"
  done
}

hub_resolve_latest_for_prefix() {
  local ns="$1" repo="$2" prefix="$3" sep="$4"
  local latest="" max=-1
  while IFS= read -r name; do
    if [[ "$name" =~ ^${prefix//./\\.}${sep}([0-9]+)$ ]]; then
      local n="${BASH_REMATCH[1]}"
      (( n > max )) && { max="$n"; latest="$name"; }
    fi
  done < <(hub_fetch_all_tag_names "$ns" "$repo")
  [[ -n "$latest" ]] && printf '%s\n' "$latest"
}

hub_suggest_next_number() {
  local registry="$1" ns="$2" repo="$3" prefix="$4" sep="$5"
  if [[ "$registry" != "docker.io" && "$registry" != "index.docker.io" ]]; then
    echo "1"
    return 0
  fi
  local latest tag_num
  latest="$(hub_resolve_latest_for_prefix "$ns" "$repo" "$prefix" "$sep" 2>/dev/null || true)"
  if [[ -z "$latest" ]]; then
    echo "1"
  else
    tag_num="${latest##${prefix}${sep}}"
    if [[ "$tag_num" =~ ^[0-9]+$ ]]; then
      echo $(( tag_num + 1 ))
    else
      echo "1"
    fi
  fi
}

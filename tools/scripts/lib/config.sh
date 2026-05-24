#!/usr/bin/env bash
set -euo pipefail

require_tools_for_config() {
  if ! command -v yq >/dev/null 2>&1; then
    echo "Error: 'yq' is required to read YAML config." >&2
    exit 1
  fi
}

cfg_get_image() {
  local file="$1"
  yq -r '.image // .Image // ""' "$file"
}

cfg_get_str() {
  local file="$1" query="$2" default="${3:-}"
  yq -r "${query} // \"${default}\"" "$file"
}

cfg_get_map_keys() {
  local file="$1" query="$2"
  yq -r "${query} | keys[]?" "$file"
}

# Ambil build args untuk build_type. Mendukung env.<type>.build_args atau build-args
cfg_get_build_args_for_env() {
  local file="$1" build_type="$2"
  # pilih properti mana yang ada
  local base="env.${build_type}"
  local has_build_args has_build_dash_args
  has_build_args="$(yq -e ".${base}.build_args" "$file" >/dev/null 2>&1 && echo yes || echo no)"
  has_build_dash_args="$(yq -e ".${base}.\"build-args\"" "$file" >/dev/null 2>&1 && echo yes || echo no)"

  if [[ "$has_build_args" == "yes" ]]; then
    yq -r ".${base}.build_args | to_entries[] | \"\(.key)=\(.value)\"" "$file"
    return 0
  fi
  if [[ "$has_build_dash_args" == "yes" ]]; then
    yq -r ".${base}.\"build-args\" | to_entries[] | \"\(.key)=\(.value)\"" "$file"
    return 0
  fi

  # Fallback ke env.default
  base="env.default"
  has_build_args="$(yq -e ".${base}.build_args" "$file" >/dev/null 2>&1 && echo yes || echo no)"
  has_build_dash_args="$(yq -e ".${base}.\"build-args\"" "$file" >/dev/null 2>&1 && echo yes || echo no)"
  if [[ "$has_build_args" == "yes" ]]; then
    yq -r ".${base}.build_args | to_entries[] | \"\(.key)=\(.value)\"" "$file"
    return 0
  fi
  if [[ "$has_build_dash_args" == "yes" ]]; then
    yq -r ".${base}.\"build-args\" | to_entries[] | \"\(.key)=\(.value)\"" "$file"
    return 0
  fi

  return 1
}

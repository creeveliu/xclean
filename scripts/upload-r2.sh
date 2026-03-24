#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_INPUT="${1:-}"
DRY_RUN="${2:-}"
BUCKET="${XCLEAN_R2_BUCKET:-xclean}"
PREFIX="${XCLEAN_R2_PREFIX:-xclean}"
DIST_DIR="$ROOT_DIR/dist"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/upload-r2.sh <version> [--dry-run]

Examples:
  bash scripts/upload-r2.sh 0.1.4
  bash scripts/upload-r2.sh v0.1.4 --dry-run

Environment:
  XCLEAN_R2_BUCKET  Target R2 bucket name (default: xclean)
  XCLEAN_R2_PREFIX  Object key prefix inside the bucket (default: xclean)
EOF
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

normalize_tag() {
  case "$1" in
    v*) printf '%s\n' "$1" ;;
    *) printf 'v%s\n' "$1" ;;
  esac
}

normalize_version() {
  printf '%s\n' "${1#v}"
}

put_object() {
  local source_file="$1"
  local object_key="$2"

  [ -f "$source_file" ] || fail "missing file: $source_file"

  local cmd=(
    wrangler r2 object put "$BUCKET/$object_key"
    --remote
    --file "$source_file"
  )

  if [ "$DRY_RUN" = "--dry-run" ]; then
    printf '[dry-run] %s\n' "${cmd[*]}"
    return 0
  fi

  "${cmd[@]}"
}

main() {
  [ -n "$VERSION_INPUT" ] || {
    usage
    exit 1
  }

  [ -z "$DRY_RUN" ] || [ "$DRY_RUN" = "--dry-run" ] || fail "unsupported flag: $DRY_RUN"

  need_cmd wrangler

  local tag_version
  local bare_version
  tag_version="$(normalize_tag "$VERSION_INPUT")"
  bare_version="$(normalize_version "$VERSION_INPUT")"

  put_object "$ROOT_DIR/install.sh" "$PREFIX/install.sh"
  put_object "$DIST_DIR/xclean-macos-arm64.tar.gz" "$PREFIX/releases/latest/download/xclean-macos-arm64.tar.gz"
  put_object "$DIST_DIR/xclean-macos-x86_64.tar.gz" "$PREFIX/releases/latest/download/xclean-macos-x86_64.tar.gz"
  put_object "$DIST_DIR/xclean-$bare_version-macos-arm64.tar.gz" "$PREFIX/releases/download/$tag_version/xclean-macos-arm64.tar.gz"
  put_object "$DIST_DIR/xclean-$bare_version-macos-x86_64.tar.gz" "$PREFIX/releases/download/$tag_version/xclean-macos-x86_64.tar.gz"
  put_object "$DIST_DIR/sha256sums.txt" "$PREFIX/releases/download/$tag_version/sha256sums.txt"

  if [ "$DRY_RUN" = "--dry-run" ]; then
    printf '\nDry run complete.\n'
  else
    printf '\nUploaded release assets to R2 bucket %s.\n' "$BUCKET"
  fi
}

main "$@"

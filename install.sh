#!/usr/bin/env bash

set -euo pipefail

REPO_URL="${XCLEAN_REPO_URL:-https://github.com/creeveliu/xclean.git}"
REF="${XCLEAN_INSTALL_REF:-main}"
VERSION="${XCLEAN_INSTALL_VERSION:-latest}"
RELEASE_BASE_URL="${XCLEAN_RELEASE_BASE_URL:-https://github.com/creeveliu/xclean/releases}"
INSTALL_DIR="${XCLEAN_INSTALL_DIR:-$HOME/.local/bin}"
TMP_ROOT="${TMPDIR:-/tmp}"
BUILD_ROOT="$(mktemp -d "$TMP_ROOT/xclean-install.XXXXXX")"

cleanup() {
  rm -rf "$BUILD_ROOT"
}

trap cleanup EXIT

log() {
  printf '%s\n' "$1"
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

detect_arch() {
  case "$(uname -m)" in
    arm64) printf 'arm64\n' ;;
    x86_64) printf 'x86_64\n' ;;
    *) fail "unsupported macOS architecture: $(uname -m)" ;;
  esac
}

ensure_path_hint() {
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
      log ""
      log "Add this to your shell profile if needed:"
      log "  export PATH=\"$INSTALL_DIR:\$PATH\""
      ;;
  esac
}

detect_macos() {
  [ "$(uname -s)" = "Darwin" ] || fail "xclean currently supports macOS only"
}

artifact_url() {
  local arch="$1"
  local artifact_name="xclean-macos-$arch.tar.gz"

  if [ "$VERSION" = "latest" ]; then
    printf '%s/latest/download/%s\n' "$RELEASE_BASE_URL" "$artifact_name"
  else
    printf '%s/download/%s/%s\n' "$RELEASE_BASE_URL" "$VERSION" "$artifact_name"
  fi
}

download_prebuilt() {
  local arch="$1"
  local url
  url="$(artifact_url "$arch")"
  local archive="$BUILD_ROOT/$arch.tar.gz"
  local extract_dir="$BUILD_ROOT/prebuilt"

  need_cmd curl
  need_cmd tar

  log "Trying prebuilt binary..."
  if ! curl -fsSL "$url" -o "$archive"; then
    return 1
  fi

  mkdir -p "$extract_dir"
  tar -xzf "$archive" -C "$extract_dir" || return 1

  local binary
  binary="$(find "$extract_dir" -type f -name xclean -perm -111 | head -n 1)"
  [ -n "$binary" ] || return 1

  mkdir -p "$INSTALL_DIR"
  cp "$binary" "$INSTALL_DIR/xclean"
  chmod 755 "$INSTALL_DIR/xclean"
  return 0
}

clone_source() {
  log "Cloning xclean source..."
  git clone --depth 1 --branch "$REF" "$REPO_URL" "$BUILD_ROOT/src" >/dev/null 2>&1 || \
    fail "failed to clone $REPO_URL at ref $REF"
}

build_binary() {
  log "Building xclean..."
  (
    cd "$BUILD_ROOT/src"
    swift build -c release >/dev/null
  ) || fail "swift build failed"
}

install_binary() {
  mkdir -p "$INSTALL_DIR"
  cp "$BUILD_ROOT/src/.build/release/xclean" "$INSTALL_DIR/xclean"
  chmod 755 "$INSTALL_DIR/xclean"
}

main() {
  local arch
  detect_macos
  arch="$(detect_arch)"

  if download_prebuilt "$arch"; then
    log "Installed prebuilt xclean to $INSTALL_DIR/xclean"
  else
    log "Prebuilt download unavailable. Falling back to source build."
    need_cmd git
    need_cmd swift
    clone_source
    build_binary
    log "Installing to $INSTALL_DIR/xclean..."
    install_binary
  fi

  log ""
  log "Installed xclean $(\"$INSTALL_DIR/xclean\" --version)"
  log "Run:"
  log "  xclean"
  ensure_path_hint
}

main "$@"

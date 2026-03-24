#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-$(swift run --package-path "$ROOT_DIR" xclean --version)}"
ARCH="$(uname -m)"
OUT_DIR="$ROOT_DIR/dist"
STAGE_DIR="$OUT_DIR/xclean-$VERSION-macos-$ARCH"
VERSIONED_ARCHIVE="xclean-$VERSION-macos-$ARCH.tar.gz"
LATEST_ARCHIVE="xclean-macos-$ARCH.tar.gz"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
mkdir -p "$OUT_DIR"

swift build --package-path "$ROOT_DIR" -c release
cp "$ROOT_DIR/.build/release/xclean" "$STAGE_DIR/xclean"
cp "$ROOT_DIR/README.md" "$STAGE_DIR/README.md"

(
  cd "$OUT_DIR"
  tar -czf "$VERSIONED_ARCHIVE" "$(basename "$STAGE_DIR")"
  cp "$VERSIONED_ARCHIVE" "$LATEST_ARCHIVE"
)

shasum -a 256 \
  "$OUT_DIR/$VERSIONED_ARCHIVE" \
  "$OUT_DIR/$LATEST_ARCHIVE" \
  | tee "$OUT_DIR/sha256sums.txt"

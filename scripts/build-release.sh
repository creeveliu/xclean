#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-$(swift run --package-path "$ROOT_DIR" xclean --version)}"
OUT_DIR="$ROOT_DIR/dist"
ARCHES=("arm64" "x86_64")

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

for ARCH in "${ARCHES[@]}"; do
  TRIPLE="$ARCH-apple-macosx13.0"
  BUILD_DIR_ARCH="$ARCH-apple-macosx"
  STAGE_DIR="$OUT_DIR/xclean-$VERSION-macos-$ARCH"
  VERSIONED_ARCHIVE="xclean-$VERSION-macos-$ARCH.tar.gz"
  LATEST_ARCHIVE="xclean-macos-$ARCH.tar.gz"

  swift build --package-path "$ROOT_DIR" -c release --triple "$TRIPLE" --product xclean
  rm -rf "$STAGE_DIR"
  mkdir -p "$STAGE_DIR"
  cp "$ROOT_DIR/.build/$BUILD_DIR_ARCH/release/xclean" "$STAGE_DIR/xclean"
  cp "$ROOT_DIR/README.md" "$STAGE_DIR/README.md"

  (
    cd "$OUT_DIR"
    tar -czf "$VERSIONED_ARCHIVE" "$(basename "$STAGE_DIR")"
    cp "$VERSIONED_ARCHIVE" "$LATEST_ARCHIVE"
  )
done

shasum -a 256 "$OUT_DIR"/*.tar.gz | tee "$OUT_DIR/sha256sums.txt"
